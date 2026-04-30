import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:permission_handler/permission_handler.dart';

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
  String _curVer = "";             // 메인 성경
  List<String> _compareVers = [];  // 대조 성경 목록 (다중 선택)
  String _curBook = "1";
  String _curChap = "1";
  double _fontSize = 22.0;         // 기본 글자 크기
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  // 외부 .lfa 파일명에 따른 예쁘게 보여줄 이름 매핑
  final Map<String, String> _lfaNameMap = {
    "korhrv": "개역한글 (외부)",
    "kornkrv": "개역개정 (외부)",
    "korklb": "현대인의 성경 (외부)",
    "koreasy": "쉬운성경 (외부)",
    "engNIV": "영어 NIV (외부)",
    "ENGKJV": "영어 KJV (외부)",
    // 필요한 이름이 있다면 계속 추가 가능합니다.
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Download/bible 폴더에서 .lfa 파일을 찾아 파싱하는 함수
  Future<void> _loadExternalLfaFiles() async {
    if (await Permission.manageExternalStorage.request().isGranted || 
        await Permission.storage.request().isGranted) {
      
      final directory = Directory('/storage/emulated/0/Download/bible');
      
      if (await directory.exists()) {
        List<FileSystemEntity> files = directory.listSync();
        final RegExp pat = RegExp(r'.*?(\d{2})_(\d+)\.[lL][fF][bB]$');

        for (var file in files) {
          if (file.path.toLowerCase().endsWith('.lfa')) {
            String fileName = file.path.split('/').last.split('.').first;
            String displayName = _lfaNameMap[fileName] ?? "$fileName (외부)";
            
            try {
              final bytes = File(file.path).readAsBytesSync();
              final archive = ZipDecoder().decodeBytes(bytes);

              Map<String, dynamic> bookData = {};

              for (final archiveFile in archive) {
                if (archiveFile.isFile) {
                  final match = pat.firstMatch(archiveFile.name);
                  if (match != null) {
                    final bk = int.parse(match.group(1)!).toString();
                    final ch = int.parse(match.group(2)!).toString();

                    final content = utf8.decode(archiveFile.content as List<int>, allowMalformed: true);
                    final lines = content.split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty && !l.startsWith('[source'))
                        .toList();

                    if (!bookData.containsKey(bk)) bookData[bk] = {};
                    bookData[bk][ch] = lines;
                  }
                }
              }

              if (bookData.isNotEmpty) {
                _data![displayName] = bookData;
                if (!_versions.contains(displayName)) {
                  _versions.add(displayName);
                }
                debugPrint("$displayName 외부 로딩 완료!");
              }

            } catch (e) {
              debugPrint("파일 읽기 에러 (${file.path}): $e");
            }
          }
        }
      } else {
        // 폴더가 없으면 사용자가 나중에 넣을 수 있게 미리 생성
        await directory.create(recursive: true);
      }
    } else {
      debugPrint("저장소 권한이 거부되었습니다.");
    }
  }

  Future<void> _loadData() async {
    try {
      // 1. 기본 내장 JSON 데이터 불러오기
      final String jsonString = await rootBundle.loadString('assets/bible.json');
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      _data = jsonData['bibles'];
      _bookNames = Map<String, String>.from(jsonData['book_names']);
      _versions = _data!.keys.toList();

      // 2. 외부 다운로드 폴더에서 .lfa 파일 불러와서 합치기
      await _loadExternalLfaFiles();

      setState(() {
        if (_versions.isNotEmpty) {
          _curVer = _versions.contains("개역한글 (기본)") ? "개역한글 (기본)" : 
                    (_versions.contains("개역한글") ? "개역한글" : _versions.first);
        }
        _isLoading = false;
      });
      _loadSettings();
    } catch (e) {
      debugPrint("Error loading data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _curVer = prefs.getString('ver') ?? _curVer;
      _compareVers = prefs.getStringList('compareVers') ?? []; 
      _curBook = prefs.getString('book') ?? "1";
      _curChap = prefs.getString('chap') ?? "1";
      _fontSize = prefs.getDouble('fontSize') ?? 22.0; 
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ver', _curVer);
    prefs.setStringList('compareVers', _compareVers); 
    prefs.setString('book', _curBook);
    prefs.setString('chap', _curChap);
    prefs.setDouble('fontSize', _fontSize); 
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

    final mainTextList = _data![_curVer][_curBook][_curChap] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${_bookNames[_curBook] ?? '성경'} $_curChap장", 
              style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 20)),
            Text(
              "$_curVer ${_compareVers.isNotEmpty ? '+ ${_compareVers.join(", ")}' : ''}", 
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
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
                                fontSize: _fontSize, 
                                height: 1.5,
                                fontWeight: FontWeight.w500
                              )),
                          ),
                        ],
                      ),
                      
                      // 대조 성경 다중 렌더링
                      if (_compareVers.isNotEmpty)
                        ..._compareVers.where((ver) => _data!.containsKey(ver)).map((compVer) {
                          final compTextList = _data![compVer][_curBook][_curChap] as List<dynamic>? ?? [];
                          if (index < compTextList.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8, left: 30),
                              child: Text(
                                "└ [$compVer] ${compTextList[index]}",
                                style: GoogleFonts.nanumMyeongjo(
                                  color: Colors.grey, 
                                  fontSize: _fontSize * 0.75, 
                                  height: 1.4
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }),
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF333333),
        onPressed: _showSelectionModal,
        child: const Icon(Icons.list, color: Colors.amber),
      ),
    );
  }

  void _openDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          builder: (_, controller) {
            return StatefulBuilder( 
              builder: (BuildContext context, StateSetter setModalState) {
                return ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // 글자 크기 설정
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("글자 크기", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                              onPressed: () {
                                if (_fontSize > 10) {
                                  setModalState(() => _fontSize -= 2);
                                  setState(() {});
                                  _saveSettings();
                                }
                              },
                            ),
                            Text("${_fontSize.toInt()}", style: const TextStyle(color: Colors.white, fontSize: 18)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                              onPressed: () {
                                if (_fontSize < 50) {
                                  setModalState(() => _fontSize += 2);
                                  setState(() {});
                                  _saveSettings();
                                }
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const Divider(color: Colors.grey, height: 40),

                    // 메인 성경 설정
                    const Text("메인 성경 선택", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ..._versions.map((v) => RadioListTile<String>(
                      title: Text(v, style: const TextStyle(color: Colors.white)),
                      value: v,
                      groupValue: _curVer,
                      activeColor: Colors.amber,
                      onChanged: (val) {
                        setModalState(() {
                          _curVer = val!;
                          _compareVers.remove(_curVer);
                        });
                        setState(() {});
                        _saveSettings();
                        Navigator.pop(context); // 메인 성경 선택 시 바텀시트 닫기
                      },
                    )),
                    const Divider(color: Colors.grey, height: 40),
                    
                    // 대조 성경 설정
                    const Text("함께 볼 성경 (대조 다중선택)", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Text("여러 개를 선택하여 동시에 비교할 수 있습니다.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    ..._versions.where((v) => v != _curVer).map((v) => CheckboxListTile(
                      title: Text(v, style: TextStyle(color: _compareVers.contains(v) ? Colors.amber : Colors.white)),
                      value: _compareVers.contains(v),
                      activeColor: Colors.amber,
                      checkColor: Colors.black,
                      onChanged: (bool? isChecked) {
                        setModalState(() {
                          if (isChecked == true) {
                            _compareVers.add(v);
                          } else {
                            _compareVers.remove(v);
                          }
                        });
                        setState(() {});
                        _saveSettings();
                      },
                    )),
                  ],
                );
              }
            );
          },
        );
      },
    );
  }

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
