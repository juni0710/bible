import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

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
        fontFamily: 'sans-serif', 
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
  Map<String, dynamic> _data = {};
  List<String> _versions = [];
  
  final Map<String, String> _bookNames = {
    "1": "창세기", "2": "출애굽기", "3": "레위기", "4": "민수기", "5": "신명기",
    "6": "여호수아", "7": "사사기", "8": "룻기", "9": "사무엘상", "10": "사무엘하",
    "11": "열왕기상", "12": "열왕기하", "13": "역대상", "14": "역대하", "15": "에스라",
    "16": "느헤미야", "17": "에스더", "18": "욥기", "19": "시편", "20": "잠언",
    "21": "전도서", "22": "아가", "23": "이사야", "24": "예레미야", "25": "예레미야애가",
    "26": "에스겔", "27": "다니엘", "28": "호세아", "29": "요엘", "30": "아모스",
    "31": "오바댜", "32": "요나", "33": "미가", "34": "나훔", "35": "하박국",
    "36": "스바냐", "37": "학개", "38": "스가랴", "39": "말라기", "40": "마태복음",
    "41": "마가복음", "42": "누가복음", "43": "요한복음", "44": "사도행전", "45": "로마서",
    "46": "고린도전서", "47": "고린도후서", "48": "갈라디아서", "49": "에베소서", "50": "빌립보서",
    "51": "골로새서", "52": "데살로니가전서", "53": "데살로니가후서", "54": "디모데전서", "55": "디모데후서",
    "56": "디도서", "57": "빌레몬서", "58": "히브리서", "59": "야고보서", "60": "베드로전서",
    "61": "베드로후서", "62": "요한일서", "63": "요한이서", "64": "요한삼서", "65": "유다서",
    "66": "요한계시록"
  };

  final Map<String, String> _availableDownloads = {
    "korhrv": "개역한글 (기본)",
    "kornkrv": "개역개정",
    "korklb": "현대인의 성경",
    "koreasy": "쉬운성경",
    "korHKJV": "킹제임스 흠정역",
    "korcath": "가톨릭 성경",
    "kordob": "우리말 성경",
    "kornrsv": "새번역",
    "korktv": "바른성경",
    "korNKCB": "공동번역 개정판",
    "kornkcb": "공동번역 개정판 (기타)", 
    "kchhrv": "국한문 개역한글",
    "kchnkrv": "국한문 개역개정",
    "kchktv": "국한문 바른성경",
    "engNIV": "영어 NIV",
    "ENGKJV": "영어 KJV",
    "engNASB": "영어 NASB",
    "engnlt": "영어 NLT",
    "chnncv": "중국어 (NCV)",
    "chnncvtr": "중국어 (번체)",
    "chnunisimpnospace": "중국어 (간체)",
    "jpnjct": "일본어 (JCT)",
    "jpnnew": "일본어 (신역)",
    "vietnamese": "베트남어",
    "spnrei": "스페인어",
    "gerlut": "독일어",
    "latvul": "라틴어"
  };

  String _curVer = "";
  List<String> _compareVers = [];
  String _curBook = "1";
  String _curChap = "1";
  double _fontSize = 22.0;
  bool _isLoading = true;
  String _errorMessage = "";

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadExternalLfaFiles();
  }

  Future<bool> _requestStoragePermission() async {
    if (await Permission.manageExternalStorage.request().isGranted) return true;
    if (await Permission.storage.request().isGranted) return true;
    return false;
  }

  Future<void> _loadExternalLfaFiles() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      if (await _requestStoragePermission()) {
        final directory = Directory('/storage/emulated/0/Download/bible');
        
        if (await directory.exists()) {
          List<FileSystemEntity> files = directory.listSync();
          final RegExp pat = RegExp(r'.*?(\d{2})_(\d+)\.[lL][fF][bB]$');
          bool fileFound = false;
          _data.clear();
          _versions.clear();

          for (var file in files) {
            if (file.path.toLowerCase().endsWith('.lfa')) {
              fileFound = true;
              
              // 대소문자 & 다운로드 번호 '(1)' 등 무시하고 깔끔한 이름 추출
              String rawFileName = file.path.split('/').last.split('.').first;
              String cleanName = rawFileName.split(' ').first.toLowerCase();
              
              String displayName = rawFileName;
              // 매핑 딕셔너리에서 대소문자 무시하고 찰떡같이 찾기
              for (var entry in _availableDownloads.entries) {
                if (entry.key.toLowerCase() == cleanName) {
                  displayName = entry.value;
                  break;
                }
              }
              
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
                  _data[displayName] = bookData;
                  if (!_versions.contains(displayName)) {
                    _versions.add(displayName);
                  }
                } else {
                   // ZIP 안은 열리는데 성경 데이터가 없는 경우도 불량으로 간주
                   throw Exception("성경 데이터가 비어있음");
                }
              } catch (e) {
                debugPrint("파싱 에러 및 자동 삭제 (${file.path}): $e");
                // 불량 파일 자동 청소 (다시 다운받을 수 있게 지워줌)
                try {
                  File(file.path).deleteSync();
                } catch (_) {}
              }
            }
          }

          if (!fileFound && _versions.isEmpty) {
            _errorMessage = "다운로드된 성경이 없습니다.\n아래 버튼을 눌러주세요.";
          }
        } else {
          await directory.create(recursive: true);
          _errorMessage = "성경 데이터 폴더를 생성했습니다.\n아래 버튼을 눌러주세요.";
        }
      } else {
        _errorMessage = "파일 접근 권한이 필요합니다.\n설정에서 허용해주세요.";
      }
    } catch (e) {
      _errorMessage = "오류가 발생했습니다.\n$e";
    }

    setState(() {
      if (_versions.isNotEmpty && !_versions.contains(_curVer)) {
        _curVer = _versions.first;
      }
      _isLoading = false;
    });

    if (_versions.isNotEmpty) {
      _loadSettings();
    }
  }

  Future<void> _downloadMultipleFromGithub(List<String> fileNames) async {
    if (fileNames.isEmpty) return;

    if (!await _requestStoragePermission()) {
      setState(() => _errorMessage = "저장소 권한이 필요합니다.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = "다운로드를 준비 중입니다...";
    });

    int successCount = 0;
    List<String> failedFiles = [];

    try {
      final directory = Directory('/storage/emulated/0/Download/bible');
      if (!await directory.exists()) await directory.create(recursive: true);

      for (int i = 0; i < fileNames.length; i++) {
        String fileName = fileNames[i];
        String displayName = _availableDownloads[fileName] ?? fileName;
        
        setState(() {
          _errorMessage = "[$displayName] 다운로드 중... (${i + 1}/${fileNames.length})";
        });

        final url = 'https://raw.githubusercontent.com/juni0710/bible/main/assets/bibles/$fileName.lfa';
        final savePath = '${directory.path}/$fileName.lfa';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          try {
            // 안전장치: 다운로드 후 껍데기가 아닌 정상적인 ZIP 파일인지 먼저 검증
            ZipDecoder().decodeBytes(response.bodyBytes);
            
            final file = File(savePath);
            await file.writeAsBytes(response.bodyBytes);
            successCount++;
          } catch (e) {
             failedFiles.add("$displayName(손상됨)");
          }
        } else {
          failedFiles.add(displayName);
        }
      }

      await _loadExternalLfaFiles(); 

      if (failedFiles.isNotEmpty) {
        setState(() {
          _errorMessage = "다운로드 완료 ($successCount 성공).\n실패 항목: ${failedFiles.join(', ')}";
        });
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "다운로드 중 오류 발생:\n$e";
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String savedVer = prefs.getString('ver') ?? "";
      if (_versions.contains(savedVer)) _curVer = savedVer;
      
      List<String> savedCompareVers = prefs.getStringList('compareVers') ?? [];
      _compareVers = savedCompareVers.where((ver) => _versions.contains(ver)).toList();
      
      _curBook = prefs.getString('book') ?? "1";
      _curChap = prefs.getString('chap') ?? "1";
      _fontSize = prefs.getDouble('fontSize') ?? 22.0; 
    });
  }

  Future<void> _saveSettings() async {
    if (_curVer.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('ver', _curVer);
    prefs.setStringList('compareVers', _compareVers); 
    prefs.setString('book', _curBook);
    prefs.setString('chap', _curChap);
    prefs.setDouble('fontSize', _fontSize); 
  }

  void _navigate(int direction) {
    if (_data.isEmpty || !_data.containsKey(_curVer)) return;
    int cBook = int.parse(_curBook);
    int cChap = int.parse(_curChap);
    
    if (direction == 1) { 
      if (_data[_curVer][cBook.toString()]?.containsKey((cChap + 1).toString()) == true) {
        cChap++;
      } else if (cBook < 66) {
        cBook++; cChap = 1;
      }
    } else { 
      if (cChap > 1) {
        cChap--;
      } else if (cBook > 1) {
        cBook--; cChap = 1; 
      }
    }

    setState(() { _curBook = cBook.toString(); _curChap = cChap.toString(); });
    _saveSettings();
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.amber),
              const SizedBox(height: 20),
              Text(_errorMessage.isNotEmpty ? _errorMessage : "성경 데이터를 불러오는 중...", 
                   style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            ],
          )
        )
      );
    }

    if (_errorMessage.isNotEmpty || _data.isEmpty) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF1E1E1E), title: const Text("안내")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_download_outlined, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                Text(
                  _errorMessage.isNotEmpty ? _errorMessage : "성경 데이터를 찾을 수 없습니다.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.5),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text("개역한글(기본) 빠른 다운로드", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, 
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                  ),
                  onPressed: () => _downloadMultipleFromGithub(['korhrv']),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _showDownloadModal(context), 
                  child: const Text("목록에서 직접 선택하기", style: TextStyle(color: Colors.grey))
                )
              ],
            ),
          ),
        ),
      );
    }

    final mainTextList = _data[_curVer]?[_curBook]?[_curChap] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${_bookNames[_curBook] ?? '성경'} $_curChap장", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
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
            child: mainTextList.isEmpty 
              ? const Center(child: Text("이 장에는 내용이 없습니다.", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
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
                                  style: TextStyle(
                                    color: const Color(0xFFE0E0E0), 
                                    fontSize: _fontSize, 
                                    height: 1.5,
                                    fontWeight: FontWeight.w500
                                  )),
                              ),
                            ],
                          ),
                          if (_compareVers.isNotEmpty)
                            ..._compareVers.where((ver) => _data.containsKey(ver)).map((compVer) {
                              final compTextList = _data[compVer]?[_curBook]?[_curChap] as List<dynamic>? ?? [];
                              if (index < compTextList.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8, left: 30),
                                  child: Text(
                                    "└ [$compVer] ${compTextList[index]}",
                                    style: TextStyle(
                                      color: Colors.grey, 
                                      fontSize: _fontSize, 
                                      height: 1.5 
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
          Container(
            color: const Color(0xFF1E1E1E),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Row(
              children: [
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => _navigate(-1), child: const Text("이전", style: TextStyle(fontWeight: FontWeight.bold)))),
                const SizedBox(width: 20),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  onPressed: () => _navigate(1), child: const Text("다음", style: TextStyle(fontWeight: FontWeight.bold)))),
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

  void _showDownloadModal(BuildContext context) {
    Set<String> selectedFiles = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      isScrollControlled: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.85, 
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("성경 다운로드 센터", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.grey),
                              onPressed: () => Navigator.pop(ctx),
                            )
                          ],
                        ),
                        const SizedBox(height: 5),
                        const Text("필요한 성경을 체크하고 하단의 다운로드 버튼을 누르세요.\n(초록색 체크는 이미 설치된 성경입니다)", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.grey, height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      children: _availableDownloads.entries.map((entry) {
                        String fileCode = entry.key;
                        String displayName = entry.value;
                        bool isDownloaded = _versions.contains(displayName);
                        
                        return CheckboxListTile(
                          title: Text(displayName, style: TextStyle(color: isDownloaded ? Colors.grey : Colors.white, fontWeight: isDownloaded ? FontWeight.normal : FontWeight.bold)),
                          subtitle: isDownloaded ? const Text("설치됨", style: TextStyle(color: Colors.green, fontSize: 12)) : null,
                          value: isDownloaded ? true : selectedFiles.contains(fileCode),
                          activeColor: isDownloaded ? Colors.green : Colors.amber,
                          checkColor: Colors.black,
                          onChanged: isDownloaded ? null : (bool? value) {
                            setModalState(() {
                              if (value == true) {
                                selectedFiles.add(fileCode);
                              } else {
                                selectedFiles.remove(fileCode);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      border: Border(top: BorderSide(color: Color(0xFF333333)))
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(selectedFiles.isEmpty ? "선택된 항목이 없습니다" : "${selectedFiles.length}개 항목 일괄 다운로드", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedFiles.isEmpty ? Colors.grey : Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15)
                      ),
                      onPressed: selectedFiles.isEmpty ? null : () {
                        Navigator.pop(ctx);
                        _downloadMultipleFromGithub(selectedFiles.toList());
                      },
                    ),
                  )
                ],
              );
            }
          ),
        );
      }
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
                        Navigator.pop(context);
                      },
                    )),
                    const Divider(color: Colors.grey, height: 40),
                    
                    const Text("함께 볼 성경 (대조)", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
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
                    const Divider(color: Colors.grey, height: 40),
                    
                    const Text("성경 추가 관리", style: TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_download),
                      label: const Text("다운로드 센터 열기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                      onPressed: () {
                         Navigator.pop(context); 
                         _showDownloadModal(context); 
                      },
                    )
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
                      style: TextStyle(color: (i+1).toString() == _curBook ? Colors.amber : Colors.grey, fontWeight: (i+1).toString() == _curBook ? FontWeight.bold : FontWeight.normal)),
                    onTap: () {
                      setState(() { _curBook = (i+1).toString(); _curChap = "1"; });
                      Navigator.pop(context);
                      _saveSettings();
                      if (_scrollController.hasClients) _scrollController.jumpTo(0);
                    },
                  ),
                ),
              ),
              const VerticalDivider(color: Colors.grey),
              Expanded(
                child: ListView.builder(
                  itemCount: _data[_curVer]?[_curBook]?.length ?? 0,
                  itemBuilder: (c, i) => ListTile(
                    title: Text("${i+1}장", style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      setState(() { _curChap = (i+1).toString(); });
                      Navigator.pop(context);
                      _saveSettings();
                      if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
