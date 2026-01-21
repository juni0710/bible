import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아버지 성경',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.amber,
        useMaterial3: true,
      ),
      home: const BiblePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BiblePage extends StatefulWidget {
  const BiblePage({super.key});

  @override
  State<BiblePage> createState() => _BiblePageState();
}

class _BiblePageState extends State<BiblePage> {
  Map<String, dynamic>? _data;
  List<String> _versions = [];
  Map<String, String> _bookNames = {}; // ID -> Name

  String _curVer = "";
  String _curBook = "1";
  String _curChap = "1";
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1. JSON 데이터 로드
      final String jsonString = await rootBundle.loadString('assets/bible.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        _data = jsonData['bibles'];
        _bookNames = Map<String, String>.from(jsonData['book_names']);
        _versions = _data!.keys.toList();
        
        // 기본값 설정 (저장된 위치가 없으면)
        if (_versions.isNotEmpty) {
          _curVer = _versions.contains("개역한글") ? "개역한글" : _versions.first;
        }
        _isLoading = false;
      });
      _loadLastPosition();
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> _loadLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _curVer = prefs.getString('ver') ?? _curVer;
      _curBook = prefs.getString('book') ?? "1";
      _curChap = prefs.getString('chap') ?? "1";
    });
  }

  Future<void> _savePosition() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ver', _curVer);
    prefs.setString('book', _curBook);
    prefs.setString('chap', _curChap);
  }

  void _navigate(int direction) {
    // 간단한 이동 로직 (다음 장/이전 장)
    int cBook = int.parse(_curBook);
    int cChap = int.parse(_curChap);
    
    if (direction == 1) { // 다음
      // 현재 권의 다음 장이 있는지 확인
      if (_data![_curVer][cBook.toString()].containsKey((cChap + 1).toString())) {
        cChap++;
      } else if (cBook < 66) {
        cBook++;
        cChap = 1;
      }
    } else { // 이전
      if (cChap > 1) {
        cChap--;
      } else if (cBook > 1) {
        cBook--;
        // 이전 권의 마지막 장 찾기 (단순화: 일단 1장으로 이동 후 로직 개선 가능)
        cChap = 1; 
      }
    }

    setState(() {
      _curBook = cBook.toString();
      _curChap = cChap.toString();
    });
    _savePosition();
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }

    // 현재 장의 데이터 가져오기
    final currentTextList = _data![_curVer][_curBook][_curChap] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text("${_bookNames[_curBook] ?? '성경'} $_curChap장", 
          style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.amber), onPressed: _showSelectionModal),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: currentTextList.length,
              separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF333333)),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${index + 1} ", 
                        style: GoogleFonts.nanumMyeongjo(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(currentTextList[index].toString(),
                          style: GoogleFonts.nanumMyeongjo(color: const Color(0xFFE0E0E0), fontSize: 22, height: 1.6)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => _navigate(-1), child: const Text("이전"))),
                const SizedBox(width: 20),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => _navigate(1), child: const Text("다음"))),
              ],
            ),
          )
        ],
      ),
      drawer: _buildDrawer(),
    );
  }

  // 메뉴 (버전 선택 등)
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.amber))),
            child: Center(child: Text("성경 선택", style: TextStyle(color: Colors.amber, fontSize: 24))),
          ),
          ..._versions.map((v) => ListTile(
            title: Text(v, style: TextStyle(color: _curVer == v ? Colors.amber : Colors.white)),
            leading: const Icon(Icons.book, color: Colors.grey),
            onTap: () {
              setState(() { _curVer = v; _curBook = "1"; _curChap = "1"; });
              _savePosition();
              Navigator.pop(context);
            },
          )).toList()
        ],
      ),
    );
  }

  // 성경/장 선택 모달
  void _showSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      builder: (ctx) {
        return SizedBox(
          height: 400,
          child: Row(
            children: [
              // 권 선택
              Expanded(
                child: ListView.builder(
                  itemCount: 66,
                  itemBuilder: (c, i) => ListTile(
                    title: Text(_bookNames[(i+1).toString()] ?? "", 
                      style: TextStyle(color: (i+1).toString() == _curBook ? Colors.amber : Colors.grey)),
                    onTap: () {
                      setState(() { _curBook = (i+1).toString(); _curChap = "1"; });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              const VerticalDivider(color: Colors.grey),
              // 장 선택
              Expanded(
                child: ListView.builder(
                  itemCount: _data![_curVer][_curBook].length,
                  itemBuilder: (c, i) => ListTile(
                    title: Text("${i+1}장", style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() { _curChap = (i+1).toString(); });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}