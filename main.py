# -*- coding: utf-8 -*-
"""
Created on Wed Jan 21 21:42:08 2026

@author: JY
"""

import flet as ft
import os
import zipfile
import re
import sys

# ==========================================
# 0. 파일명 -> 한글 이름 매핑 (설정)
# ==========================================
# 여기에 없는 파일은 그냥 파일명 그대로 표시됩니다.
BIBLE_NAMES = {
    # --- 한국어 ---
    "korhrv.lfa": "개역한글 (기본)",
    "kornkrv.lfa": "개역개정",
    "korklb.lfa": "현대인의 성경",
    "koreasy.lfa": "쉬운성경",
    "korHKJV.lfa": "킹제임스 흠정역",
    "korcath.lfa": "가톨릭 성경",
    "kordob.lfa": "우리말 성경",
    "kornrsv.lfa": "새번역",
    "korktv.lfa": "바른성경",
    "korNKCB.lfa": "공동번역 개정판",
    "kornkcb.lfa": "공동번역 개정판", # 소문자 대비
    "kchhrv.lfa": "국한문 개역한글",
    "kchnkrv.lfa": "국한문 개역개정",
    "kchktv.lfa": "국한문 바른성경",
    
    # --- 영어 ---
    "engNIV.lfa": "영어 NIV",
    "ENGKJV.lfa": "영어 KJV (King James)",
    "engNASB.lfa": "영어 NASB",
    "engnlt.lfa": "영어 NLT",
    
    # --- 중국어 ---
    "chnncv.lfa": "중국어 (NCV)",
    "chnncvtr.lfa": "중국어 (번체)",
    "chnunisimpnospace.lfa": "중국어 (간체)",
    "ckjvsimp.lfa": "중국어 (KJV)",

    # --- 일본어 ---
    "jpnjct.lfa": "일본어 (JCT)",
    "jpnnew.lfa": "일본어 (신역)",
    "jpnnit.lfa": "일본어 (NIT)",

    # --- 기타 ---
    "gerlut.lfa": "독일어 (Luther)",
    "spnrei.lfa": "스페인어",
    "vietnamese.lfa": "베트남어",
    "latvul.lfa": "라틴어 (Vulgate)"
}

# 성경이 아닌 파일들은 목록에서 제외 (구조가 달라서 에러남)
EXCLUDE_FILES = [
    "hymns.lfa", "new_hymns.lfa",       # 찬송가
    "versicles.lfa", "new_versicle.lfa" # 교독문
]

# ==========================================
# 1. 성경 데이터 처리 클래스
# ==========================================
class BibleReader:
    def __init__(self, asset_dir):
        base_path = os.path.dirname(__file__)
        self.asset_dir = os.path.join(base_path, "assets", "bibles")
        
        self.versions = []      
        self.file_maps = {}     
        self.scan_versions()

    def scan_versions(self):
        if not os.path.exists(self.asset_dir):
            os.makedirs(self.asset_dir)
            
        files = os.listdir(self.asset_dir)
        temp_list = []

        for f in files:
            # 1. .lfa 파일만 통과
            if not f.endswith('.lfa'): continue
            
            # 2. 찬송가/교독문 제외
            if f in EXCLUDE_FILES: continue
            
            # 3. 이름 매핑 (없으면 파일명 그대로)
            display_name = BIBLE_NAMES.get(f, f)
            temp_list.append((f, display_name))

        # 4. 정렬 (한국어 우선, 그다음 영어, 나머지)
        # 키 포인트: 이름에 '한글', '국한문', '성경' 등이 들어간걸 앞으로 뺌
        def sort_key(item):
            fname, dname = item
            # 우선순위 점수 (낮을수록 앞)
            if fname == "korhrv.lfa": return 0  # 개역한글 1등
            if "개역" in dname: return 1
            if "성경" in dname: return 2        # 기타 한국어
            if "영어" in dname: return 3
            return 4 # 나머지

        temp_list.sort(key=sort_key)
        self.versions = temp_list # [(filename, displayname), ...]

    def load_version_map(self, version_file):
        if version_file in self.file_maps: return True

        path = os.path.join(self.asset_dir, version_file)
        try:
            with zipfile.ZipFile(path, 'r') as zf:
                temp_map = {}
                pattern = re.compile(r'.*?(\d{2})_(\d+)\.[lL][fF][bB]$')

                for file_in_zip in zf.namelist():
                    match = pattern.match(file_in_zip)
                    if match:
                        book_idx = int(match.group(1))
                        chap_idx = int(match.group(2))
                        temp_map[(book_idx, chap_idx)] = file_in_zip
                
                self.file_maps[version_file] = temp_map
                return True
        except Exception as e:
            print(f"Error loading map for {version_file}: {e}")
            return False

    def get_text_lines(self, version_file, book_idx, chap_idx):
        self.load_version_map(version_file)
        ver_map = self.file_maps.get(version_file)
        if not ver_map: return []
        
        target_file = ver_map.get((book_idx, chap_idx))
        if not target_file: return []

        try:
            path = os.path.join(self.asset_dir, version_file)
            with zipfile.ZipFile(path, 'r') as zf:
                with zf.open(target_file) as f:
                    content = f.read()
                    try:
                        text = content.decode('cp949')
                    except UnicodeDecodeError:
                        text = content.decode('utf-8')
                    
                    clean_lines = []
                    for line in text.splitlines():
                        line = line.strip()
                        if not line: continue
                        if line.startswith("[source"): continue 
                        clean_lines.append(line)
                    return clean_lines
        except Exception:
            return []

# ==========================================
# 2. UI 구성
# ==========================================
def main(page: ft.Page):
    page.title = "아버지 성경 (다국어 대조)"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 10
    
    reader = BibleReader("./assets/bibles")
    
    # 버전이 하나도 없으면 경고
    if not reader.versions:
        page.add(ft.Text("assets/bibles 폴더에 .lfa 파일이 없습니다."))
        return

    # 초기 상태: (파일명)
    initial_ver_file = reader.versions[0][0] # 정렬된 첫번째 파일(korhrv)
    initial_ver_name = reader.versions[0][1]

    state = {
        "primary_file": initial_ver_file, 
        "primary_name": initial_ver_name,
        "compare_files": [], # 대조할 파일명 리스트
        "book": 1,
        "chapter": 1
    }

    bible_list = ft.ListView(expand=True, spacing=15)

    def render_text():
        bible_list.controls.clear()
        
        # 메인 성경
        primary_lines = reader.get_text_lines(state["primary_file"], state["book"], state["chapter"])
        
        # 대조 성경 데이터 로딩
        compare_data = {} 
        for v_file in state["compare_files"]:
            compare_data[v_file] = reader.get_text_lines(v_file, state["book"], state["chapter"])

        # 데이터가 아예 없으면 표시
        if not primary_lines:
             bible_list.controls.append(ft.Text("내용이 없습니다.", size=20))
        
        for i, p_line in enumerate(primary_lines):
            controls_in_verse = [
                ft.Text(p_line, size=22, weight=ft.FontWeight.BOLD, selectable=True)
            ]
            
            # 대조 성경 표시
            for v_file in state["compare_files"]:
                # 파일명으로 해당 성경의 표시 이름 찾기
                display_name = next((name for fname, name in reader.versions if fname == v_file), v_file)
                
                c_lines = compare_data.get(v_file, [])
                if i < len(c_lines):
                    controls_in_verse.append(
                        ft.Text(f"└ [{display_name}] {c_lines[i]}", 
                                size=16, color=ft.colors.GREY_400, selectable=True)
                    )

            bible_list.controls.append(
                ft.Column(controls=controls_in_verse, spacing=2)
            )

        page.title = f"{state['primary_name']} - {state['book']}권 {state['chapter']}장"
        page.update()

    # --- 이벤트 핸들러 ---
    def on_prev_click(e):
        if state["chapter"] > 1:
            state["chapter"] -= 1
            render_text()

    def on_next_click(e):
        reader.load_version_map(state["primary_file"])
        ver_map = reader.file_maps[state["primary_file"]]
        
        if (state["book"], state["chapter"] + 1) in ver_map:
            state["chapter"] += 1
            render_text()
        elif (state["book"] + 1, 1) in ver_map:
            state["book"] += 1
            state["chapter"] = 1
            render_text()

    def on_primary_ver_change(e):
        # 드롭다운에서 선택된 값(파일명)으로 업데이트
        selected_file = primary_dropdown.value
        # 표시 이름 찾기
        for fname, dname in reader.versions:
            if fname == selected_file:
                state["primary_file"] = fname
                state["primary_name"] = dname
                break
        
        state["book"] = 1
        state["chapter"] = 1
        render_text()

    # 대조 설정 창
    def open_compare_dialog(e):
        def close_dlg(e):
            compare_dialog.open = False
            page.update()

        def save_compare_settings(e):
            selected = []
            # 체크박스들의 data 속성에 파일명을 넣어둠
            for checkbox in checkbox_col.controls:
                if checkbox.value:
                    selected.append(checkbox.data) # data=파일명
            
            # 메인 성경과 겹치면 제외
            if state["primary_file"] in selected:
                selected.remove(state["primary_file"])

            state["compare_files"] = selected
            close_dlg(None)
            render_text()

        checkbox_col = ft.Column(scroll=ft.ScrollMode.AUTO)
        
        for fname, dname in reader.versions:
            is_checked = fname in state["compare_files"]
            is_disabled = (fname == state["primary_file"])
            
            checkbox_col.controls.append(
                ft.Checkbox(
                    label=dname,   # 보여주는 건 한글 이름
                    data=fname,    # 실제 값은 파일명
                    value=is_checked, 
                    disabled=is_disabled
                )
            )

        compare_dialog = ft.AlertDialog(
            title=ft.Text("함께 볼 성경 선택"),
            content=ft.Container(
                content=checkbox_col, 
                height=400, width=300
            ),
            actions=[
                ft.TextButton("취소", on_click=close_dlg),
                ft.TextButton("적용", on_click=save_compare_settings),
            ],
        )
        page.dialog = compare_dialog
        compare_dialog.open = True
        page.update()

    # --- UI 배치 ---
    # 드롭다운 옵션 생성 (text=보여줄이름, key=파일명)
    dropdown_opts = [ft.dropdown.Option(key=fname, text=dname) for fname, dname in reader.versions]
    
    primary_dropdown = ft.Dropdown(
        options=dropdown_opts,
        width=220,
        label="성경 선택",
        value=state["primary_file"], # 초기값
        on_change=on_primary_ver_change,
        text_size=16,
    )

    compare_btn = ft.ElevatedButton(
        "대조 설정", 
        icon=ft.icons.SETTINGS, 
        on_click=open_compare_dialog,
        bgcolor=ft.colors.BLUE_GREY_700,
        color=ft.colors.WHITE
    )

    top_bar = ft.Row(
        controls=[primary_dropdown, compare_btn],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN
    )

    bottom_bar = ft.Row(
        controls=[
            ft.ElevatedButton("◀ 이전", on_click=on_prev_click, height=50, width=100),
            ft.ElevatedButton("다음 ▶", on_click=on_next_click, height=50, width=100),
        ],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN
    )

    page.add(top_bar, ft.Divider(), bible_list, ft.Divider(), bottom_bar)
    render_text()

ft.app(target=main)