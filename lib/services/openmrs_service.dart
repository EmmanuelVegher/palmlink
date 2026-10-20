import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/patient_model.dart';
import 'vector_matcher.dart';

class OpenMrsService {
  /// OpenMRS REST API Endpoints Reference
  static const String openMrsRestPatientEndpoint = "/ws/rest/v1/patient?v=full&limit=100";
  static const String openMrsRestPatientDefaultEndpoint = "/ws/rest/v1/patient?v=default&limit=100";
  static const String openMrsFhirPatientEndpoint = "/ws/fhir2/R4/Patient";
  static const String openMrsIdentifierTypesEndpoint = "/ws/rest/v1/patientidentifiertype";
  static const String openMrsSessionEndpoint = "/ws/rest/v1/session";

  /// Custom HTTP client that bypasses self-signed SSL verification for local network OpenMRS servers
  static http.Client _createUnsecureClient() {
    final HttpClient ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  /// Generates a deterministic seed vector for newly imported patients prior to biometric snapping
  static List<double> generateInitialSeedVector(String seedString) {
    int seed = seedString.hashCode;
    List<double> vec = [];
    for (int i = 0; i < 128; i++) {
      vec.add(sin(seed * 0.7 + i * 0.15) * 0.5 + 0.5);
    }
    return VectorMatcher.normalizeL2(vec);
  }

  /// Connects to OpenMRS / NMRS local network REST API and fetches patient bio-data
  static Future<List<PatientModel>> fetchPatientsFromOpenMrs({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    // Clean URL trailing slash
    String cleanUrl = serverUrl.trim();
    if (cleanUrl.endsWith("/")) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }

    if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
      cleanUrl = "http://$cleanUrl";
    }

    final String basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    final http.Client client = kIsWeb ? http.Client() : _createUnsecureClient();

    // Try endpoints in order of richness
    final List<String> candidateEndpoints = [
      "$cleanUrl$openMrsRestPatientEndpoint",
      "$cleanUrl$openMrsRestPatientDefaultEndpoint",
      "$cleanUrl$openMrsFhirPatientEndpoint",
    ];

    http.Response? lastResponse;
    Exception? lastException;

    for (final endpoint in candidateEndpoints) {
      try {
        debugPrint("🌐 Attempting OpenMRS Connection to: $endpoint");

        final response = await client.get(
          Uri.parse(endpoint),
          headers: {
            'Authorization': basicAuth,
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          lastResponse = response;
          break; // Successfully fetched JSON data!
        } else {
          lastResponse = response;
        }
      } on SocketException catch (se) {
        final errStr = se.toString().toLowerCase();
        if (errStr.contains("connection refused") || errStr.contains("errno = 111") || errStr.contains("errno = 61")) {
          lastException = Exception("🔌 OpenMRS Server Offline (Connection Refused). Apache Tomcat is not started on your laptop server ($cleanUrl). Please launch Tomcat/OpenMRS and tap connect again!");
        } else {
          lastException = Exception("Network Unreachable. Ensure your phone and laptop hosting OpenMRS are on the same Wi-Fi network ($cleanUrl).");
        }
      } on HandshakeException catch (he) {
        lastException = Exception("SSL Certificate Error ($he). Verify your OpenMRS server protocol (http vs https).");
      } catch (e) {
        lastException = Exception("Connection Failed: $e");
      }
    }

    if (lastResponse == null) {
      throw lastException ?? Exception("Could not establish connection to OpenMRS server at $cleanUrl");
    }

    if (lastResponse.statusCode != 200) {
      if (lastResponse.body.contains("<!DOCTYPE html>") || lastResponse.body.contains("<html")) {
        throw Exception("OpenMRS Authentication Failed (HTTP ${lastResponse.statusCode}). Server redirected to login page. Check your Username & Password.");
      }
      throw Exception("OpenMRS Server returned HTTP status ${lastResponse.statusCode}: ${lastResponse.body.substring(0, min(200, lastResponse.body.length))}");
    }

    // Check if response is HTML login page
    final String bodyText = lastResponse.body.trim();
    if (bodyText.startsWith("<") || bodyText.contains("<!DOCTYPE html>")) {
      throw Exception("OpenMRS returned HTML login page. Authentication failed. Verify Username & Password.");
    }

    try {
      final Map<String, dynamic> data = jsonDecode(bodyText);

      // 1. Standard OpenMRS REST Structure ({ "results": [...] })
      if (data.containsKey('results')) {
        final List<dynamic> results = data['results'] ?? [];
        return _parseOpenMrsRestResults(results);
      }
      
      // 2. FHIR R4 Structure ({ "resourceType": "Bundle", "entry": [...] })
      if (data.containsKey('entry')) {
        final List<dynamic> entries = data['entry'] ?? [];
        return _parseOpenMrsFhirEntries(entries);
      }

      return [];
    } on FormatException catch (fe) {
      throw Exception("Failed to parse OpenMRS response: Invalid JSON ($fe)");
    }
  }

  static List<PatientModel> _parseOpenMrsRestResults(List<dynamic> results) {
    List<PatientModel> importedPatients = [];

    for (var item in results) {
      final String uuid = item['uuid'] ?? "";
      final Map<String, dynamic> person = item['person'] ?? {};
      
      // Parse Full Name
      String fullName = item['display'] ?? "";
      final List<dynamic> names = person['names'] ?? item['names'] ?? [];
      if (names.isNotEmpty) {
        final nameObj = names[0];
        final givenName = nameObj['givenName'] ?? "";
        final familyName = nameObj['familyName'] ?? "";
        fullName = "$givenName $familyName".trim();
      }
      if (fullName.isEmpty) fullName = "OpenMRS Patient";

      // Parse Patient ID (MRN)
      String mrn = "PL-${uuid.substring(0, min(6, uuid.length)).toUpperCase()}";
      final List<dynamic> identifiers = item['identifiers'] ?? [];
      if (identifiers.isNotEmpty) {
        mrn = identifiers[0]['identifier'] ?? mrn;
      }

      // Parse Gender
      String rawGender = person['gender'] ?? item['gender'] ?? "M";
      String gender = (rawGender.toUpperCase() == "F" || rawGender.toUpperCase() == "FEMALE") ? "Female" : "Male";

      // Parse Age
      int age = (person['age'] ?? item['age']) is num ? ((person['age'] ?? item['age']) as num).toInt() : 30;

      // Parse Phone Number
      String phone = "";
      final List<dynamic> attributes = person['attributes'] ?? item['attributes'] ?? [];
      for (var attr in attributes) {
        final attrType = attr['attributeType']?['display'] ?? "";
        if (attrType.toLowerCase().contains("phone") || attrType.toLowerCase().contains("telephone")) {
          phone = attr['value'] ?? "";
          break;
        }
      }

      final seedVector = generateInitialSeedVector(uuid.isNotEmpty ? uuid : mrn);

      importedPatients.add(
        PatientModel(
          id: uuid.isNotEmpty ? uuid : DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: mrn,
          fullName: fullName,
          gender: gender,
          age: age,
          phoneNumber: phone,
          bloodGroup: "O+",
          palmEmbedding: seedVector,
          leftPalmEmbedding: seedVector,
          registeredAt: DateTime.now(),
        ),
      );
    }

    return importedPatients;
  }

  static List<PatientModel> _parseOpenMrsFhirEntries(List<dynamic> entries) {
    List<PatientModel> importedPatients = [];

    for (var entry in entries) {
      final resource = entry['resource'] ?? {};
      final String id = resource['id'] ?? "";
      
      String fullName = "OpenMRS Patient";
      final List<dynamic> nameList = resource['name'] ?? [];
      if (nameList.isNotEmpty) {
        final nameObj = nameList[0];
        final given = (nameObj['given'] as List?)?.join(" ") ?? "";
        final family = nameObj['family'] ?? "";
        fullName = "$given $family".trim();
      }

      String mrn = "PL-${id.substring(0, min(6, id.length)).toUpperCase()}";
      final List<dynamic> identifiers = resource['identifier'] ?? [];
      if (identifiers.isNotEmpty) {
        mrn = identifiers[0]['value'] ?? mrn;
      }

      String rawGender = resource['gender'] ?? "male";
      String gender = rawGender.toLowerCase().startsWith("f") ? "Female" : "Male";

      importedPatients.add(
        PatientModel(
          id: id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString(),
          patientId: mrn,
          fullName: fullName,
          gender: gender,
          age: 30,
          phoneNumber: "",
          bloodGroup: "O+",
          palmEmbedding: const [],
          leftPalmEmbedding: null,
          rightPalmEmbedding: null,
          registeredAt: DateTime.now(),
        ),
      );
    }

    return importedPatients;
  }

  /// Parses CSV patient records into PatientModel list
  static List<PatientModel> parseCsvPatients(String csvContent) {
    final List<String> lines = const LineSplitter().convert(csvContent.trim());
    if (lines.isEmpty) return [];

    List<PatientModel> patients = [];
    int startIndex = 0;

    // Check if line 0 is a header line
    final firstLineLower = lines[0].toLowerCase();
    if (firstLineLower.contains("name") || firstLineLower.contains("id") || firstLineLower.contains("gender")) {
      startIndex = 1;
    }

    for (int i = startIndex; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(RegExp(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'));
      if (parts.length < 2) continue;

      String name = parts[0].replaceAll('"', '').trim();
      String mrn = parts.length > 1 ? parts[1].replaceAll('"', '').trim() : "PL-${10000 + i}";
      String gender = parts.length > 2 ? parts[2].replaceAll('"', '').trim() : "Male";
      int age = parts.length > 3 ? (int.tryParse(parts[3].replaceAll('"', '').trim()) ?? 30) : 30;
      String phone = parts.length > 4 ? parts[4].replaceAll('"', '').trim() : "";
      String bloodGroup = parts.length > 5 ? parts[5].replaceAll('"', '').trim() : "O+";

      // Normalize gender format
      if (gender.toLowerCase().startsWith("f")) {
        gender = "Female";
      } else if (gender.toLowerCase().startsWith("m")) {
        gender = "Male";
      }

      patients.add(
        PatientModel(
          id: "CSV-$i-${DateTime.now().millisecondsSinceEpoch}",
          patientId: mrn,
          fullName: name,
          gender: gender,
          age: age,
          phoneNumber: phone,
          bloodGroup: bloodGroup,
          palmEmbedding: const [],
          leftPalmEmbedding: null,
          rightPalmEmbedding: null,
          registeredAt: DateTime.now(),
        ),
      );
    }

    return patients;
  }
}
