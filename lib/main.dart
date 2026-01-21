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
  Map<String, String> _bookNames = {};

  // 상태 변수
  String _curVer = "";       // 메인 성경 (예: 개역한글)
  String? _compareVer;       // 대조 성경 (예: 영어NIV, 없으면 null)
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
      final String jsonString = await rootBundle.loadString('assets/bible.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      setState(() {
        _data = jsonData['bibles'];
        _bookNames = Map<String, String>.from(jsonData['book_names']);
        _versions = _data!.keys.toList();
        
        // 기본값: 개역한글 우선, 없으면 첫 번째
        if (_versions.isNotEmpty) {
          _curVer = _versions.contains("개역한글 (기본)") ? "개역한글 (기본)" : 
                    (_versions.contains("개역한글") ? "개역한글" : _versions.first);
        }
        _isLoading = false;
      });
      _loadSettings();
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _curVer = prefs.getString('ver') ?? _curVer;
      _compareVer = prefs.getString('compare'); // 대조 성경 불러오기
      if (_compareVer == "") _compareVer = null; // 빈 문자열이면 null 처리
      
      _curBook = prefs.getString('book') ?? "1";
      _curChap = prefs.getString('chap') ?? "1";
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ver', _curVer);
    if (_compareVer != null) {
      prefs.setString('compare', _compareVer!);
    } else {
      prefs.remove('compare');
    }
    prefs.setString('book', _curBook);
    prefs.setString('chap', _curChap);
  }

  void _navigate(int direction) {
    int cBook = int.parse(_curBook);
    int cChap = int.parse(_curChap);
    
    if (direction == 1) { // 다음
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
        cChap = 1; 
      }
    }

    setState(() {
      _curBook = cBook.toString();
      _curChap = cChap.toString();
    });
    _saveSettings();
    _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.amber)));
    }

    // 데이터 가져오기
    final mainTextList = _data![_curVer][_curBook][_curChap] as List<dynamic>? ?? [];
    List<dynamic> compareTextList = [];
    
    // 대조 성경이 선택되어 있으면 가져오기
    if (_compareVer != null && _data!.containsKey(_compareVer)) {
       compareTextList = _data![_compareVer][_curBook][_curChap] as List<dynamic>? ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${_bookNames[_curBook] ?? '성경'} $_curChap장", 
              style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 20)),
            // 어떤 성경인지 작게 표시
            Text("$_curVer ${ _compareVer != null ? '+ $_compareVer' : ''}", 
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.menu, color: Colors.amber), onPressed: () => _openDrawer(context)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: mainTextList.length,
              separatorBuilder: (ctx, i) => const Divider(color: Color(0xFF333333)),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 절 번호 + 메인 성경
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text("${index + 1}", 
                              style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Text(mainTextList[index].toString(),
                              style: GoogleFonts.nanumMyeongjo(
                                color: const Color(0xFFE0E0E0), 
                                fontSize: 22, // 메인 성경은 크게
                                height: 1.5,
                                fontWeight: FontWeight.w500
                              )),
                          ),
                        ],
                      ),
                      
                      // 대조 성경 (있을 때만 표시)
                      if (_compareVer != null && index < compareTextList.length)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 30), // 들여쓰기
                          child: Text(
                            "└ [$_compareVer] ${compareTextList[index]}",
                            style: GoogleFonts.nanumMyeongjo(
                              color: Colors.grey, // 회색으로 연하게
                              fontSize: 16,       // 조금 작게
                              height: 1.4
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          // 하단 이동 버튼
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
      // 권/장 선택용 하단 팝업 (제목 클릭 시)
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF333333),
        onPressed: _showSelectionModal,
        child: const Icon(Icons.list, color: Colors.amber),
      ),
    );
  }

  // --- 메뉴 (Drawer) ---
  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(20),
              children: [
                const Text("메인 성경 선택", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ..._versions.map((v) => RadioListTile<String>(
                  title: Text(v, style: const TextStyle(color: Colors.white)),
                  value: v,
                  groupValue: _curVer,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    setState(() { _curVer = val!; });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                )),
                const Divider(color: Colors.grey, height: 40),
                
                const Text("함께 볼 성경 (대조)", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("선택하면 메인 성경 아래에 같이 나옵니다.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 10),
                
                // '없음' 옵션 추가
                RadioListTile<String?>(
                  title: const Text("(대조 없음)", style: TextStyle(color: Colors.grey)),
                  value: null,
                  groupValue: _compareVer,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    setState(() { _compareVer = null; });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                ),
                ..._versions.map((v) => RadioListTile<String?>(
                  title: Text(v, style: TextStyle(color: _compareVer == v ? Colors.amber : Colors.white)),
                  value: v,
                  groupValue: _compareVer,
                  activeColor: Colors.amber,
                  onChanged: (val) {
                    // 메인 성경과 같으면 대조 의미 없으니 체크
                    if (val == _curVer) return; 
                    setState(() { _compareVer = val; });
                    _saveSettings();
                    Navigator.pop(context);
                  },
                )),
              ],
            );
          },
        );
      },
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