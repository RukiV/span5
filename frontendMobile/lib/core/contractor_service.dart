import 'package:flutter/material.dart';
import '../models/contractor.dart';
import 'api_client.dart';

class ContractorService {
  static final List<Contractor> _contractors = [];
  static final ValueNotifier<List<Contractor>> contractorsNotifier = ValueNotifier(_contractors);

  static Future<void> fetchContractors() async {
    try {
      final response = await ApiClient().client.get('/contractors');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _contractors.clear();
        _contractors.addAll(data.map((json) => Contractor.fromJson(json)).toList());
        contractorsNotifier.value = List.from(_contractors);
      }
    } catch (e) {
      debugPrint("Error fetching contractors: $e");
    }
  }

  static Future<bool> addContractor(Contractor contractor) async {
    try {
      final response = await ApiClient().client.post('/contractors', data: contractor.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchContractors();
        return true;
      }
    } catch (e) {
      debugPrint("Error adding contractor: $e");
    }
    return false;
  }

  static Future<bool> updateContractor(Contractor contractor) async {
    try {
      final response = await ApiClient().client.patch('/contractors/${contractor.id}', data: contractor.toJson());
      if (response.statusCode == 200) {
        await fetchContractors();
        return true;
      }
    } catch (e) {
      debugPrint("Error updating contractor: $e");
    }
    return false;
  }

  static Future<bool> deleteContractor(int id) async {
    try {
      final response = await ApiClient().client.delete('/contractors/$id');
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchContractors();
        return true;
      }
    } catch (e) {
      debugPrint("Error deleting contractor: $e");
    }
    return false;
  }
}
