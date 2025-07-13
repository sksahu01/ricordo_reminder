import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Reminder App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.grey[50],
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: Colors.grey[800],
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.grey[850],
          foregroundColor: Colors.white,
        ),
      ),
      themeMode: ThemeMode.system,
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    RemindersScreen(),
    AddReminderScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Reminders'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class Reminder {
  String id;
  String title;
  DateTime dateTime;
  String notes;
  RepeatInterval repeatInterval;
  int reminderMinutes;
  String ringtone;

  Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.notes = '',
    this.repeatInterval = RepeatInterval.none,
    this.reminderMinutes = 60,
    this.ringtone = 'Default',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'notes': notes,
      'repeatInterval': repeatInterval.toString(),
      'reminderMinutes': reminderMinutes,
      'ringtone': ringtone,
    };
  }

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'],
      title: json['title'],
      dateTime: DateTime.parse(json['dateTime']),
      notes: json['notes'] ?? '',
      repeatInterval: RepeatInterval.values.firstWhere(
        (e) => e.toString() == json['repeatInterval'],
        orElse: () => RepeatInterval.none,
      ),
      reminderMinutes: json['reminderMinutes'] ?? 5,
      ringtone: json['ringtone'] ?? 'Default',
    );
  }

  int get daysLeft {
    final now = DateTime.now();
    final reminderTime = dateTime.subtract(Duration(minutes: reminderMinutes));
    return reminderTime.difference(now).inDays;
  }

  String get timeLeft {
    final now = DateTime.now();
    final reminderTime = dateTime.subtract(Duration(minutes: reminderMinutes));
    final difference = reminderTime.difference(now);

    if (difference.isNegative) return 'Overdue';

    if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes left';
    } else {
      return 'Due now';
    }
  }
}

enum RepeatInterval { none, daily, weekly, monthly, yearly }

extension RepeatIntervalExtension on RepeatInterval {
  String get displayName {
    switch (this) {
      case RepeatInterval.none:
        return 'No Repeat';
      case RepeatInterval.daily:
        return 'Daily';
      case RepeatInterval.weekly:
        return 'Weekly';
      case RepeatInterval.monthly:
        return 'Monthly';
      case RepeatInterval.yearly:
        return 'Yearly';
    }
  }
}

class ReminderStorage {
  static const String _key = 'reminders';

  static Future<List<Reminder>> getReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson = prefs.getStringList(_key) ?? [];
    return remindersJson
        .map((json) => Reminder.fromJson(jsonDecode(json)))
        .toList();
  }

  static Future<void> saveReminders(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final remindersJson =
        reminders.map((reminder) => jsonEncode(reminder.toJson())).toList();
    await prefs.setStringList(_key, remindersJson);
  }
}

class RemindersScreen extends StatefulWidget {
  @override
  _RemindersScreenState createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> reminders = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _timer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadReminders() async {
    final loadedReminders = await ReminderStorage.getReminders();
    setState(() {
      reminders = loadedReminders;
    });
  }

  Future<void> _deleteReminder(String id) async {
    setState(() {
      reminders.removeWhere((reminder) => reminder.id == id);
    });
    await ReminderStorage.saveReminders(reminders);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Reminders'),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadReminders),
        ],
      ),
      body:
          reminders.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No reminders yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap the + button to add your first reminder',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
              : ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: reminders.length,
                itemBuilder: (context, index) {
                  final reminder = reminders[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColor,
                        child: Icon(Icons.notifications, color: Colors.white),
                      ),
                      title: Text(
                        reminder.title,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'MMM dd, yyyy - HH:mm',
                            ).format(reminder.dateTime),
                          ),
                          if (reminder.notes.isNotEmpty)
                            Text(
                              reminder.notes,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 16, color: Colors.grey),
                              SizedBox(width: 4),
                              Text(reminder.repeatInterval.displayName),
                              SizedBox(width: 16),
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4),
                              Text('${reminder.reminderMinutes}min before'),
                            ],
                          ),
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  reminder.daysLeft < 0
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              reminder.timeLeft,
                              style: TextStyle(
                                color:
                                    reminder.daysLeft < 0
                                        ? Colors.red
                                        : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteDialog(reminder),
                      ),
                    ),
                  );
                },
              ),
    );
  }

  void _showDeleteDialog(Reminder reminder) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Reminder'),
            content: Text(
              'Are you sure you want to delete "${reminder.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteReminder(reminder.id);
                },
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}

class AddReminderScreen extends StatefulWidget {
  @override
  _AddReminderScreenState createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatInterval _repeatInterval = RepeatInterval.none;
  int _reminderMinutes = 60;
  String _selectedRingtone = 'Default';

  final List<String> _ringtones = [
    'Default',
    'Alarm Clock',
    'Bell',
    'Chime',
    'Digital',
    'Gentle',
    'Marimba',
    'Radar',
  ];

  final List<int> _reminderOptions = [
    1,
    5,
    10,
    15,
    30,
    60,
    120,
    240,
    480,
    1440,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Reminder'),
        actions: [
          TextButton(
            onPressed: _saveReminder,
            child: Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (optional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.calendar_today),
                      title: Text('Date'),
                      subtitle: Text(
                        DateFormat('MMMM dd, yyyy').format(_selectedDate),
                      ),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _selectDate,
                    ),
                    Divider(),
                    ListTile(
                      leading: Icon(Icons.access_time),
                      title: Text('Time'),
                      subtitle: Text(_selectedTime.format(context)),
                      trailing: Icon(Icons.chevron_right),
                      onTap: _selectTime,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<RepeatInterval>(
                      value: _repeatInterval,
                      decoration: InputDecoration(
                        labelText: 'Repeat',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.repeat),
                      ),
                      items:
                          RepeatInterval.values.map((interval) {
                            return DropdownMenuItem(
                              value: interval,
                              child: Text(interval.displayName),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _repeatInterval = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _reminderMinutes,
                      decoration: InputDecoration(
                        labelText: 'Remind me before',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      items:
                          _reminderOptions.map((minutes) {
                            return DropdownMenuItem(
                              value: minutes,
                              child: Text(_formatReminderTime(minutes)),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _reminderMinutes = value!;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedRingtone,
                      decoration: InputDecoration(
                        labelText: 'Ringtone',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.music_note),
                      ),
                      items:
                          _ringtones.map((ringtone) {
                            return DropdownMenuItem(
                              value: ringtone,
                              child: Text(ringtone),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedRingtone = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReminderTime(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes < 1440) {
      return '${minutes ~/ 60} hours';
    } else {
      return '${minutes ~/ 1440} days';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (_formKey.currentState!.validate()) {
      final reminder = Reminder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        dateTime: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ),
        notes: _notesController.text,
        repeatInterval: _repeatInterval,
        reminderMinutes: _reminderMinutes,
        ringtone: _selectedRingtone,
      );

      final reminders = await ReminderStorage.getReminders();
      reminders.add(reminder);
      await ReminderStorage.saveReminders(reminders);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reminder saved successfully!')));

      _titleController.clear();
      _notesController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedTime = TimeOfDay.now();
        _repeatInterval = RepeatInterval.none;
        _reminderMinutes = 5;
        _selectedRingtone = 'Default';
      });
    }
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.palette),
                  title: Text('Theme'),
                  subtitle: Text('Light/Dark mode follows system settings'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notifications'),
                  subtitle: Text('Manage notification settings'),
                  trailing: Switch(value: true, onChanged: (value) {}),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Storage'),
                  subtitle: Text('All data is stored locally on your device'),
                  trailing: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info),
                  title: Text('About'),
                  subtitle: Text('Reminder App v1.0.0'),
                  trailing: Icon(Icons.chevron_right),
                ),
                Divider(),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    'Clear All Data',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: Text('Delete all reminders permanently'),
                  onTap: _showClearDataDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Clear All Data'),
            content: Text(
              'Are you sure you want to delete all reminders? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await ReminderStorage.saveReminders([]);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('All data cleared successfully!')),
                  );
                },
                child: Text('Clear All', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}
