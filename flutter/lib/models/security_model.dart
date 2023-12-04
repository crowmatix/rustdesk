import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:password_strength_checker/password_strength_checker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityProvider extends ChangeNotifier {
  bool firstSecReq = true;
  bool secondSecReq = false;
  bool thirdSecReq = false;
  bool fourthSecReq = false;
  bool fifthSecReq = false;
  bool sixthSecReq = false;
  bool seventhSecReq = false;

  bool overallSecurity = false;

  String network = "None";

  late DataTable loggingData = createDataTable();
  late DateTime sessionStartTime;

  //Second Try
  late DataTable dataTableToShow = createDataTable();

  Future<void> requirementsCheck() async {
    isSecTwoCheck();
    await isSecThreeCheck();
    await isSecFourCheck();
    await isSecFiveCheck();
    await isSecSixCheck();
    await isSecSevenCheck();

    isOverAllSecurityCheck();
  }

  void boxCheck() {
    isSecFiveCheck();
    isSecSixCheck();
    isSecSevenCheck();
  }

  void isOverAllSecurityCheck() {
    if (firstSecReq &&
        secondSecReq &&
        thirdSecReq &&
        fourthSecReq &&
        fifthSecReq &&
        sixthSecReq &&
        seventhSecReq) {
      overallSecurity = true;
    } else {
      overallSecurity = false;
    }
    notifyListeners();
  }

  void isSecTwoCheck() {
    Map<String, dynamic> oldOptions =
        jsonDecode(bind.mainGetOptionsSync() as String);
    old(String key) {
      return (oldOptions[key] ?? '').trim();
    }

    final finalKey = old('key');

    if (finalKey == '' || !_isKeySecure(finalKey)) {
      secondSecReq = false;
    } else {
      secondSecReq = true;
    }
    isOverAllSecurityCheck();
  }

  Future<void> isSecThreeCheck() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.mobile) {
      network = "Mobile";
      thirdSecReq = true;
    } else if (connectivityResult == ConnectivityResult.wifi) {
      network = "Wi-Fi";
    } else if (connectivityResult == ConnectivityResult.ethernet) {
      network = "Ethernet";
      thirdSecReq = true;
    } else if (connectivityResult == ConnectivityResult.vpn) {
      network = "VPN";
      thirdSecReq = true;
    } else if (connectivityResult == ConnectivityResult.other) {
      network = "Other";
    } else if (connectivityResult == ConnectivityResult.none) {
      network = "None";
    }
  }

  Future<void> isSecFourCheck() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool? reqFour = prefs.getBool('reqFour');
    if (reqFour != null) {
      fourthSecReq = reqFour;
    }
    //getSavedLogs();
    //await prefs.remove('loggingStringList');
  }

  Future<void> isSecFiveCheck() async {
    final optionKey = 'allow-auto-disconnect';
    bool enabled =
        option2bool(optionKey, bind.mainGetOptionSync(key: optionKey));

    if (enabled) {
      fifthSecReq = true;
    } else {
      fifthSecReq = false;
    }
    isOverAllSecurityCheck();
  }

  Future<void> isSecSixCheck() async {
    final optionKey = 'allow-auto-record-incoming';
    bool enabled =
        option2bool(optionKey, bind.mainGetOptionSync(key: optionKey));
    if (enabled) {
      sixthSecReq = true;
    } else {
      sixthSecReq = false;
    }
    isOverAllSecurityCheck();
  }

  Future<void> isSecSevenCheck() async {
    final optionKey = 'enable-check-update';
    bool enabled =
        option2bool(optionKey, bind.mainGetLocalOption(key: optionKey));
    if (enabled) {
      seventhSecReq = true;
    } else {
      seventhSecReq = false;
    }
    isOverAllSecurityCheck();
  }

  Future<void> changeFourthSecReq(bool b) async {
    fourthSecReq = b;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('reqFour', b);
    isOverAllSecurityCheck();
  }

  void changedKey(String key) {
    if (key == '' || !_isKeySecure(key)) {
      secondSecReq = false;
    } else {
      secondSecReq = true;
    }
    isOverAllSecurityCheck();
  }

  bool _isKeySecure(String key) {
    final entropy = _isKeyRandom(key);
    if (key.isNotEmpty &&
        key.length >= 32 &&
        entropy > 4 &&
        !commonDictionary.containsKey(key)) {
      return true;
    }
    return false;
  }

  DataTable createDataTable() {
    return DataTable(
      columns: [
        DataColumn(label: Text('Fernwartungs ID')),
        DataColumn(label: Text('Startzeit')),
        DataColumn(label: Text('Länge')),
      ],
      rows: [],
    );
  }

  Future<void> updateSavedListString() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedStringList = prefs.getStringList('loggingStringList');

    if (savedStringList != null) {
      List<DataRow> savedRows = [];

      for (int i = 0; i < savedStringList.length; i += 3) {
        if (i + 2 < savedStringList.length) {
          DataRow newRow = DataRow(cells: [
            DataCell(Text(savedStringList[i])),
            DataCell(Text(savedStringList[i + 1])),
            DataCell(Text(savedStringList[i + 2])),
          ]);
          savedRows.add(newRow);
        }
      }
      dataTableToShow = DataTable(
        columns: dataTableToShow.columns,
        rows: savedRows,
      );
    }
  }

  Future<void> saveInitalStringList(String id) async {
    List<String> stringListToSave = [];

    //Create Timestamp
    final timeNow = DateTime.now();
    sessionStartTime = timeNow;
    String formattedTime =
        "${timeNow.day}.${timeNow.month}.${timeNow.year} - ${timeNow.hour}:";
    formattedTime += '${addZeroToString(timeNow.minute, true)}:';
    formattedTime += addZeroToString(timeNow.second, false);

    stringListToSave.add(id);
    stringListToSave.add(formattedTime);
    stringListToSave.add('---');

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedStringList = prefs.getStringList('loggingStringList');

    if (savedStringList != null) {
      savedStringList.addAll(stringListToSave);
      await prefs.setStringList('loggingStringList', savedStringList);
    } else {
      await prefs.setStringList('loggingStringList', stringListToSave);
    }
  }

  Future<void> saveStopStringList() async {
    // Get Saved List of Strings
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedStringList = prefs.getStringList('loggingStringList');

    if (savedStringList != null) {
      //Create Time Difference aka Länge
      final timeNow = DateTime.now();
      final difference = timeNow.difference(sessionStartTime);
      String timeLength = '';
      timeLength += '${addZeroToString(difference.inMinutes, true)} min ';
      timeLength += '${addZeroToString(difference.inSeconds % 60, false)} sec';

      // Striche weg und Längerein
      savedStringList.removeLast();
      savedStringList.add(timeLength);

      await prefs.setStringList('loggingStringList', savedStringList);
    }
  }

  String addZeroToString(int digit, bool minute) {
    if (minute) {
      if (digit < 10) {
        return '0$digit';
      } else {
        return '$digit';
      }
    } else {
      if (digit < 10) {
        return '0$digit';
      } else {
        return '$digit';
      }
    }
  }
}

//////

double _isKeyRandom(String key) {
  Map<String, int> map = {};

  for (int i = 0; i < key.length; i++) {
    String c = key[i];
    if (!map.containsKey(c)) {
      map[c] = 1;
    } else {
      map[c] = map[c]! + 1;
    }
  }

  double entropy = 0.0;
  int len = key.length;

  map.forEach((key, value) {
    double frequency = value / len;
    entropy -= frequency * (log(frequency) / log(2));
  });
  return entropy;
}
