import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mock_data.dart';
import 'dart:math';

void main() async {
  // Set up Hive, for documentation see here: https://github.com/isar/hive
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Open our pre-existing Hive box (or create a new one if not found),
  // to store the needed data for our application
  final box = await Hive.openBox('groups');

  // Add the necessary mock data into our Hive box
  // NOTE: We will also have a key 'groups' which will store our generated groups
  box.put('names', MockData.names);
  box.put('lessons', MockData.lessons);

  // NOTE: The location of the data stored by our Hive box will depend on which device is used, the
  // location is also determined by the following standard plugin: https://pub.dev/packages/path_provider

  // Start running our Flutter application
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of our application
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CIS*4030 Group Generator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const GroupGeneratorPage(title: 'CIS*4030 Group Generator'),
    );
  }
}

class GroupGeneratorPage extends StatefulWidget {
  const GroupGeneratorPage({super.key, required this.title});
  final String title;

  @override
  State<GroupGeneratorPage> createState() => _GroupGeneratorPageState();
}

class _GroupGeneratorPageState extends State<GroupGeneratorPage> {
  // Retrieve our Hive box containing our data
  final box = Hive.box('groups');

  // All possible view settings
  // NOTE: This very small amount of data could also be stored via Hive or Shared Preferences
  final List<String> _allViewSettings = ['Condensed', 'List', 'Tabular'];

  // State variables
  // - `_groups`: Will change when a new group is rolled by the user
  // - `_selectedViewSetting`: Will change when a new view is chosen by the user
  Map<String, List<String>> _groups = {};
  String _selectedViewSetting = 'Condensed';

  // Handle any required work for the initialization of our page/object. 
  // NOTE: `initState` is only called once when the object is inserted into the tree,
  // see the official documentation for more details: https://api.flutter.dev/flutter/widgets/State/initState.html 
  @override
  initState() {
    super.initState();
    var dynamicGroups = box.get('groups', defaultValue: {});
    _groups = _castGroups(dynamicGroups);
    _loadSettings();
  }

  // Since Hive returns data dynamically, and we are working with nested data types (e.g. `Map<String, List<String>>`),
  // we are responsible for building a function that casts it into the type we would like to work with
  Map<String, List<String>> _castGroups(groups) {
    Map<String, List<String>> castedGroups = {};
    groups.forEach((key, value) {
      if (key is String && value is List) {
        List<String> stringList = value.whereType<String>().toList();
        castedGroups[key] = stringList;
      } else {
        // We will throw an error if we cannot cast to the type we're expected to retrieve
        // This should never happen in our case, but is left here strictly for completeness
        throw TypeError();
      }
    });
    return castedGroups;
  }

  // A function that generates groups randomly based off of the provided data in our Hive box
  void _generateGroups() {
    // Retrieve our mock data which is guaranteed to exist since we have populated
    // our Hive box before running the Flutter application
    List<String> names = box.get('names');
    List<String> lessons = box.get('lessons');

    // Shuffle the list of our names and groups randomly
    names.shuffle(Random());
    lessons.shuffle(Random());

    // Generate groups with the shuffled names and lessons
    Map<String, List<String>> generatedGroups = {};
    for (int i = 0; i < names.length; i++) {
      // The behaviour below is equivalent to Python's collections.defaultdict(list)
      generatedGroups.putIfAbsent(lessons[i % lessons.length], () => []).add(names[i]);
    }

    // Add the randomly generated groups to our Hive box, if the box already exists, the data inside it will be updated
    // NOTE: Hive supports all primitive types out of the box, but if you want to store other objects or change the serialization,
    // you can use an adapter. See here for more details: https://hivedb.dev/#/custom-objects/type_adapters
    box.put('groups', generatedGroups);
    setState(() {
      _groups = generatedGroups;
    });
  }

  // A function to load our view settings using Shared Preferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedViewSetting = prefs.getString('selected_view') ?? _selectedViewSetting;
    });
  }

  // A function to update/store our view settings using Shared Preferences
  Future<void> _updateSettings(String? newSetting) async {
    // Open our shared preferences
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedViewSetting = newSetting!;
      prefs.setString('selected_view', _selectedViewSetting);
    });
  }

  // A custom ItemBuilder for our ListView which will vary depending on the current view setting
  dynamic _customItemBuilder(BuildContext context, int index) {
    final String curKey = _groups.keys.elementAt(index);
    final List<String> curValues = _groups.values.elementAt(index);

    if (_selectedViewSetting == 'Condensed') {
      // Return items using the `,` delimiter
      return 
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ListTile(
          contentPadding: EdgeInsets.all(0),
          title: Center(child: Text(curKey)),
          subtitle: Center(child: Text(curValues.join(", "))),
        )
      );
    } else if (_selectedViewSetting == 'List') {
      // Return items in an ordered list format
      return ListTile(
        contentPadding: EdgeInsets.all(0),
        title: Center(child: Text(curKey)),
        subtitle: Column(
          children: curValues.asMap().entries.map((entry) {
            int index = entry.key + 1;
            String value = entry.value;
            return Text('$index. $value');
          }).toList()
        ),
      );
    } else if (_selectedViewSetting == 'Tabular') {
      // Returns items using a tabular styled format
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          alignment: WrapAlignment.center,
          children: [
            // This child is the name of the group (i.e. Lesson 1..10)
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
              ),
              child: Text(
                curKey,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            // The rest of the children are the names belonging to this group
            ...List.generate(curValues.length, (curIndex) {
                return Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // A simple implementation of alternating colours using our colour scheme
                    color: (
                      curIndex.isEven ? 
                      Theme.of(context).colorScheme.primaryContainer : 
                      Theme.of(context).colorScheme.secondaryContainer
                    ),
                  ),
                  child: Text(
                    curValues[curIndex],
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
              );
            }),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(widget.title)),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // The "Roll" button in our Flutter application. The purpose of this button
                  // is to allow the user to generate random groups
                  ElevatedButton(
                    onPressed: () => _generateGroups(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.casino),
                        SizedBox(width: 4),
                        Text("Roll", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  // Adds space between our buttons
                  SizedBox(width: 16),
                  // The "Settings" button in our application. The purpose of this button
                  // is to allow the user to customize the view displayed data
                  DropdownButton<String>(
                    value: _selectedViewSetting,
                    items: _allViewSettings.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text("$value ", style: TextStyle(fontSize: 16)),
                      );
                    }).toList(),
                    onChanged: (String? newSetting) => _updateSettings(newSetting),
                    padding: EdgeInsets.symmetric(horizontal: 5.0),
                    icon: Icon(Icons.settings)
                  ),
                ],
              ),
            ),
            // The view of our Hive box which will depend on the currently selected view of the user
            Expanded(child: 
              ListView.builder(
                itemCount: _groups.length,
                itemBuilder: (context, index) => _customItemBuilder(context, index),
              ),
            )
          ],
        ),
      ),
    );
  }
}
