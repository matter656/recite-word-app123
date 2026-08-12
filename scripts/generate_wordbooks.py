#!/usr/bin/env python3
"""生成 4 本词书的 JSON 数据（assets/wordbooks/）。

数据来源（全部可合规商用）：
- 词表/音标/释义：ECDICT (MIT) — stardict.db 的 tag 字段提供考试归属
- 例句：Tatoeba (CC-BY 2.0) — 英文例句 + 中文翻译

用法:
  python scripts/generate_wordbooks.py \
    --stardict <stardict.db> \
    --tatoeba-dir <解压后的 tatoeba 目录(eng.tsv/cmn.tsv/links.csv)> \
    --out <输出目录>
"""
import argparse
import json
import os
import re
import sqlite3
import sys

BOOKS = [
    ("cet4", "四级核心词汇", "大学英语四级核心词汇"),
    ("cet6", "六级核心词汇", "大学英语六级核心词汇"),
    ("ky", "考研核心词汇", "考研英语核心词汇"),
    ("ielts", "雅思核心词汇", "雅思考试核心词汇"),
]

WORD_RE = re.compile(r"[A-Za-z][A-Za-z'-]*")


def extract_words(stardict_db: str, tag: str):
    """从 ECDICT stardict.db 提取某 tag 的词条。"""
    conn = sqlite3.connect(stardict_db)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()
    cur.execute(
        "SELECT word, phonetic, translation FROM stardict WHERE tag LIKE ? "
        "AND translation IS NOT NULL AND translation != '' ORDER BY word",
        (f"%{tag}%",),
    )
    rows = [dict(r) for r in cur.fetchall()]
    conn.close()
    return rows


def build_eng_index(eng_path: str, target_words: set):
    """扫描英文句子，构建 目标词 -> [句子id] 索引，并保留全部句子文本。"""
    eng_text = {}
    word_index = {}
    with open(eng_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            sid, text = parts[0], parts[2]
            eng_text[sid] = text
            seen = set()
            for tok in WORD_RE.findall(text):
                low = tok.lower()
                if low in target_words and low not in seen:
                    seen.add(low)
                    word_index.setdefault(low, []).append(sid)
    return eng_text, word_index


def build_translations(links_path: str, eng_ids: set, cmn_text: dict):
    """扫描翻译链接，构建 英文句id -> [中文句id]。"""
    trans = {}
    with open(links_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            a, b = parts[0], parts[1]
            if a in eng_ids and b in cmn_text:
                trans.setdefault(a, []).append(b)
            elif b in eng_ids and a in cmn_text:
                trans.setdefault(b, []).append(a)
    return trans


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--stardict", required=True)
    ap.add_argument("--tatoeba-dir", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--no-hans", action="store_true",
                    help="不做繁转简（默认把例句中文转为简体）")
    args = ap.parse_args()

    if not args.no_hans:
        from zhconv import convert  # noqa: E402
    else:
        def convert(s, locale):
            return s

    eng_path = os.path.join(args.tatoeba_dir, "eng.tsv")
    cmn_path = os.path.join(args.tatoeba_dir, "cmn.tsv")
    links_path = os.path.join(args.tatoeba_dir, "links.csv")

    # 中文句子 id -> 文本
    print("读取中文句子...")
    cmn_text = {}
    with open(cmn_path, encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                cmn_text[parts[0]] = parts[2]
    print(f"  中文句子 {len(cmn_text)} 条")

    # 收集所有目标词
    all_targets = set()
    for tag, _, _ in BOOKS:
        rows = extract_words(args.stardict, tag)
        for r in rows:
            all_targets.add(r["word"].lower())
    print(f"目标词（去重）: {len(all_targets)}")

    print("构建英文例句索引...")
    eng_text, word_index = build_eng_index(eng_path, all_targets)
    print(f"  英文句子 {len(eng_text)} 条, 命中 {len(word_index)} 个词")

    print("构建翻译链接...")
    trans = build_translations(links_path, set(eng_text.keys()), cmn_text)
    print(f"  英→中翻译对 {sum(len(v) for v in trans.values())} 条")

    os.makedirs(args.out, exist_ok=True)
    for tag, name, desc in BOOKS:
        rows = extract_words(args.stardict, tag)
        out_words = []
        with_example = 0
        for r in rows:
            w = r["word"].lower()
            sids = word_index.get(w, [])
            ex = None
            for sid in sids:
                cn_ids = trans.get(sid, [])
                if cn_ids:
                    ex = {"en": eng_text[sid], "cn": convert(cmn_text[cn_ids[0]], "zh-cn")}
                    break
            if ex:
                with_example += 1
            out_words.append({
                "word": r["word"],
                "phonetic": r["phonetic"] or "",
                "meaning": r["translation"],
                "example": ex,
            })
        out_path = os.path.join(args.out, f"{tag}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump({"book": tag, "name": name, "desc": desc,
                       "words": out_words}, f, ensure_ascii=False)
        print(f"  [{tag}] {len(out_words)} 词, 例句覆盖 {with_example} ({with_example * 100 // max(len(out_words), 1)}%) -> {out_path}")


if __name__ == "__main__":
    main()
