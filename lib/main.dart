import 'dart:convert';

import 'package:convert/convert.dart';

import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:terminal/scan.dart'; // Update the import path as needed
import 'package:xterm/xterm.dart';

void main() {
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  static BluetoothDevice? connectedDevice;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyTerminalPage(key: MyTerminalPage.terminalKey),
    );
  }
}

class MyTerminalPage extends StatefulWidget {
  static final GlobalKey<_MyTerminalPageState> terminalKey = GlobalKey<_MyTerminalPageState>();

  MyTerminalPage({required GlobalKey<_MyTerminalPageState> key});

  @override
  _MyTerminalPageState createState() => _MyTerminalPageState();
}

class _MyTerminalPageState extends State<MyTerminalPage> with SingleTickerProviderStateMixin {
  late Terminal terminal;
  late TabController tabController;
  TextEditingController userInputController = TextEditingController();

  List<BluetoothService>? services;
  String string = '';

  @override
  void initState() {
    super.initState();

    terminal = Terminal();
    terminal.write('Welcome to the Bushers Recovery!\n');

    tabController = TabController(length: 5, vsync: this);
    tabController.addListener(() {
      setState(() {});
    });

    if (MyApp.connectedDevice != null) {
      connectToDevice(MyApp.connectedDevice!);
      MyApp.connectedDevice = null;
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      services = await device.discoverServices();
      setState(() {});
      terminal.write('\r\x1B[33m\rConnected to ${device.remoteId}!\n\x1B[0m');
      terminal.write('\rUser Input : ');
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }


  String hexToString(List<int> hexList) {
    return hexList.map((byte) => String.fromCharCode(byte)).join();
  }

  Future<void> onWritePressed(String command) async {
    try {
      if (services != null) {
        for (BluetoothService service in services!) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == Guid('0000ffe1-0000-1000-8000-00805f9b34fb')) {
              String hexCommand = HEX.encode(Utf8Encoder().convert(command));
              await characteristic.write((hex.decode(hexCommand))).then((value) {
                print('Success writing');
              });

              List<int> response;
              try {
                response = await characteristic.read().timeout(Duration(seconds: 5));
              } catch (timeoutError) {

                setState(() {
                  string = 'Error: Timeout';
                });
                return;
              }

              print('Immediate Device Response Hex: ${hex.encode(Uint8List.fromList(response))}');

              if (response.isEmpty) {
                setState(() {
                  string = 'Error: No response';
                });
                return;
              }

              String responseHex = hex.encode(Uint8List.fromList(response));

              setState(() {
                string = responseHex;
              });

              print('Device Response: $responseHex');
            }
          }
        }
      }
    } catch (e) {
      print('Error writing to characteristic: $e');
      setState(() {
        string = 'Error: $e';
      });
    }
  }

  void handleUserInput(String input) async {
    if (MyApp.connectedDevice == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Connect to a Device'),
            content: Text('You should connect to a Bluetooth device first.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      try {
        setState(() {
          terminal.eraseLine();
          terminal.write('\rUser Input: \x1B[33m$input\x1B[0m\n');
        });

        await onWritePressed(input);

        setState(() {
          terminal.write('\rDevice Response: \x1B[33m$string\x1B[0m\n');
        });
      } catch (error) {
        print('Error handling user input: $error');
        setState(() {
          terminal.write('\rError: $error\n');
        });
      }
    }
  }

  void handleButtonPress(String buttonText) {
    if (MyApp.connectedDevice == null) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Connect to a Device'),
            content: Text('You should connect to a Bluetooth device first.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      final userTyped = userInputController.text;
      handleUserInput(userTyped + buttonText);
      userInputController.clear();
    }
  }

  void handleKeyPress(RawKeyEvent event) {
    if (event is RawKeyUpEvent) {
      return;
    }

    final key = event.data.keyLabel;
    final userTyped = userInputController.text;

    if (key.isNotEmpty) {
      setState(() {
        terminal.eraseLine();
        terminal.write('\rUser Input: \x1B[33m$userTyped$key\x1B[0m');
      });

      userInputController.text += key;
    } else if (event.logicalKey == LogicalKeyboardKey.enter && userTyped.isNotEmpty) {
      handleUserInput(userTyped);
      userInputController.clear();
    }
  }
  final List<List<List<Map<String, String>>>> tabButtons = [
    [
      [
        {'name': 'Recovery 1', 'value': 'reboot recovery'},
        {'name': 'Recovery 2', 'value': 'cnstar'},
        {'name': 'Recovery 3', 'value': 'recovery'},
        {'name': 'Recovery 4', 'value': 'recovery_wipe_partition'},
        {'name': 'Recovery 5', 'value': 'boot_fastboot'},
        {'name': 'RESET', 'value': 'reset'},
      ],
    ],
    [
      [
        {'name': 'Recovery 1', 'value': 'reboot recovery'},
        {'name': 'Recovery 2', 'value': 'eboot recovery'},
        {'name': 'Recovery 3', 'value': 'boot recovery'},
        {'name': 'Recovery 4', 'value': 'recovery'},
        {'name': 'RESET', 'value': 'reset'},
      ],
    ],
    [
      [
        {'name': 'Recovery 1', 'value': 'recovery'},
        {'name': 'Recovery 2', 'value': 'go r'},
        {'name': 'Recovery 3', 'value': 'boot_fastboot'},
        {'name': 'Recovery 4', 'value': 'cus boot'},
        {'name': 'RESET', 'value': 'reset'},
      ],
    ],
    [
      [
        {'name': 'Recovery 1', 'value': 'recovery yes'},
        {'name': 'Recovery 2', 'value': 'rec'},
        {'name': 'RESET', 'value': 'reset'},
      ],
    ],
    [
      [
        {'name': 'Recovery 1', 'value': 'run update'},
        {'name': 'Recovery 2', 'value': 'reboot recovery'},
        {'name': 'Recovery 3', 'value': 'reboot factory_reset'},
        {'name': 'Recovery 4', 'value': 'recovery'},
        {'name': 'RESET', 'value': 'reset'},
      ],
    ],
  ];


  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bushers Recovery'),
        backgroundColor: Colors.blue,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black,
            child: TabBar(
              controller: tabController,
              indicatorColor: Colors.white,
              onTap: (index) {
                setState(() {});
              },
              tabs: [
                Tab(
                  child: Text(
                    'MASTAR',
                    style: TextStyle(fontSize: 8), // Set the font size as needed
                  ),
                ),
                Tab(
                  child: Text(
                    'MEDIATEK',
                    style: TextStyle(fontSize: 8), // Set the font size as needed
                  ),
                ),
                Tab(
                  child: Text(
                    'REALTEK',
                    style: TextStyle(fontSize: 8), // Set the font size as needed
                  ),
                ),
                Tab(
                  child: Text(
                    'HISILICON',
                    style: TextStyle(fontSize: 8), // Set the font size as needed
                  ),
                ),
                Tab(
                  child: Text(
                    'AMLOGIC',
                    style: TextStyle(fontSize: 8), // Set the font size as needed
                  ),
                ),
              ],
            ),

          ),
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(1.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child:Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: tabButtons[tabController.index]
                      .map((buttons) => buttons.map((button) => buildRedButton(button['name']!, button['value']!)).toList())
                      .expand((buttons) => buttons)
                      .toList(),
                ),
              ),
            ),
            Expanded(
              child: TerminalView(terminal),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: userInputController,
                        style: TextStyle(color: Colors.white),
                        onChanged: (value) {
                          setState(() {
                            terminal.eraseLine();
                            terminal.write('\rUser Input: \x1B[33m$value\x1B[0m');
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'User Input',
                          labelStyle: TextStyle(color: Colors.white),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    handleUserInput(userInputController.text);
                    userInputController.clear();
                  },
                  child: Text('Enter'),
                ),
              ],
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Serial Bluetooth Terminal ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            ListTile(
              title: Text('Terminal'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Devices'),
              onTap: () async {
                BluetoothDevice? selectedDevice = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ScanScreen()),
                );

                if (selectedDevice != null) {
                  connectToDevice(selectedDevice);
                }
              },
            ),
            ListTile(
              title: Text('Settings '),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }


  Widget buildRedButton(String buttonText, String buttonValue) {
    return TextButton(
      onPressed: () {
        handleButtonPress(buttonValue);
      },
      child: Text(
        '$buttonText',
        style: TextStyle(fontSize: 8, color: Colors.red),
      ),
    );
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }
}

