import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Öğrenci Notları',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: StudentScores(),
    );
  }
}

class StudentScores extends StatefulWidget {
  @override
  _StudentScoresState createState() => _StudentScoresState();
}

class _StudentScoresState extends State<StudentScores> {
  final String apiUrl = 'http://127.0.0.1:2000';

  Map<String, TextEditingController> yaziliControllers = {};
  Map<String, TextEditingController> sozluControllers = {};
  Map<String, dynamic> selectedStudent = {}; 

  Future<List<dynamic>> get9AStudents() async {
    var result = await http.get(Uri.parse('$apiUrl/students/9A'));
    if (result.statusCode == 200) {
      return json.decode(result.body);
    } else {
      throw Exception('Veri yüklenemedi');
    }
  }

  void _onStudentTap(Map<String, dynamic> student) {
    setState(() {
      selectedStudent = student;
    });
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => StudentDetailPage(student: student)),
    );
  }

  List<Widget> _buildStudentList(List<dynamic> students) {
    return students.map((student) {
      var name = student['firstName'] ?? 'İsimsiz';
      name += student['lastName'] != null ? ' ${student['lastName']}' : '';
      var studentNumber = student['schoolNumber'] ?? 'Öğrenci Numarası Belirtilmemiş';
      var average = student['grades'] != null ? student['grades']['average']?.toString() ?? 'Not Bilgisi Yok' : 'Not Bilgisi Yok';
      return Card(
        child: ListTile(
          title: Text(name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Öğrenci Numarası: $studentNumber'),
              Text('Ortalama: $average'),
            ],
          ),
          onTap: () {
            _onStudentTap(student);
          },
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('9/A Öğrenci Notları'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: get9AStudents(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Veri yüklenirken bir hata oluştu: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            List<dynamic> students = snapshot.data ?? [];
            return ListView(
              children: _buildStudentList(students),
            );
          } else {
            return Center(child: Text('Öğrenci verileri bulunamadı.'));
          }
        },
      ),
    );
  }
}

class StudentDetailPage extends StatefulWidget {
  final Map<String, dynamic> student;

  StudentDetailPage({required this.student});

  @override
  _StudentDetailPageState createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  final String apiUrl = 'http://127.0.0.1:2000';

  Map<String, TextEditingController> yaziliControllers = {};
  Map<String, TextEditingController> sozluControllers = {};

  double _calculateSubjectAverage(String subject) {
    var yazili = widget.student['grades'][subject]['yazili'].isEmpty
        ? 0
        : widget.student['grades'][subject]['yazili'][0];
    var sozlu = widget.student['grades'][subject]['sozlu'].isEmpty
        ? 0
        : widget.student['grades'][subject]['sozlu'][0];
    return (yazili + sozlu) / 2;
  }

  double _calculateOverallAverage() {
    double total = 0;
    int count = 0;
    for (var subject in widget.student['grades'].keys) {
      if (widget.student['grades'][subject]['yazili'].isNotEmpty &&
          widget.student['grades'][subject]['sozlu'].isNotEmpty) {
        total += _calculateSubjectAverage(subject);
        count++;
      }
    }
    return count > 0 ? total / count : 0;
  }

  Future<void> _updateStudentGrades(String subject) async {
    var schoolNumber = widget.student['schoolNumber'];
    var url = Uri.parse('$apiUrl/student/$schoolNumber');

    var response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        subject: {
          "yazili": [int.parse(yaziliControllers[subject]!.text)],
          "sozlu": [int.parse(sozluControllers[subject]!.text)],
          "hours": widget.student['grades'][subject]['hours'], 
        }
      }),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tüm değişiklikler kaydedildi!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: Tüm değişiklikler kaydedilmedi, yapımcı ile iletişime geçin')),
      );
    }
  }

  void _populateControllers() {
    for (var subject in widget.student['grades'].keys) {
     
      if (widget.student['grades'][subject]['yazili'].isNotEmpty) {
        yaziliControllers[subject]!.text =
            widget.student['grades'][subject]['yazili'][0].toString();
      }
      if (widget.student['grades'][subject]['sozlu'].isNotEmpty) {
        sozluControllers[subject]!.text =
            widget.student['grades'][subject]['sozlu'][0].toString();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    
    for (var subject in widget.student['grades'].keys) {
      yaziliControllers[subject] = TextEditingController();
      sozluControllers[subject] = TextEditingController();
    }
    _populateControllers();
  }

  @override
  void dispose() {
   
    for (var controller in yaziliControllers.values) {
      controller.dispose();
    }
    for (var controller in sozluControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.student['firstName']} ${widget.student['lastName'] ?? ''} Not Girişi'),
      ),
      body: ListView(
        children: <Widget>[
          for (var subject in widget.student['grades'].keys) ...[
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '$subject Not Girişi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                  ),
                  SizedBox(height: 8.0),
                  TextField(
                    controller: yaziliControllers[subject],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Yazılı Notu',
                      hintText:
                          'Önceki Not: ${widget.student['grades'][subject]['yazili'].isNotEmpty ? widget.student['grades'][subject]['yazili'][0] : 'Yok'}',
                    ),
                  ),
                  TextField(
                    controller: sozluControllers[subject],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Sözlü Notu',
                      hintText:
                          'Önceki Not: ${widget.student['grades'][subject]['sozlu'].isNotEmpty ? widget.student['grades'][subject]['sozlu'][0] : 'Yok'}',
                    ),
                  ),
                  SizedBox(height: 16.0),
                  ElevatedButton(
                    onPressed: () {
                      _updateStudentGrades(subject);
                    },
                    child: Text('Notları Kaydet'),
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    'Ortalama: ${_calculateSubjectAverage(subject).toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Genel Ortalama',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0),
                ),
                SizedBox(height: 8.0),
                Text(
                  'Ortalama: ${_calculateOverallAverage().toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
