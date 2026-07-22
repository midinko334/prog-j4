## japanim.nim
## ----------------------------------------------------------------
## 日本語DSL「japanim」を Nim ソースコードへトランスコンパイルする。
##
## パイプライン:
##   1. 行の読み込み
##   2. グルーピング : 「ここから〜ここまでを##回繰り返す」
##                      「以下を##回繰り返す」+「・」箇条書き
##                      をひとつの繰り返しブロックにまとめる
##   3. 行パース     : 各行をキーワード・助詞で分解する
##   4. Stmt構築     : 「もし〜なら」の連続行を if/elif チェーンにまとめる
##   5. 省略補完     : 主語・目的語省略時に「直前に参照した変数」で埋める
##   6. コード生成   : Stmt木からNimソースを出力する
##
## 表記ゆれ(「〜して」「〜しなさい」等)は今回は未対応。
## ----------------------------------------------------------------

import std/[strutils, sets]
import std/unicode except strip

# ============================================================
# 1. 行の読み込み
# ============================================================

proc readLogicalLines(src: string): seq[string] =
  for rawLine in src.splitLines():
    let line = rawLine.strip()
    if line.len > 0:
      result.add(line)

# ============================================================
# 2. グルーピング
#    ここから〜ここまで / 以下＋箇条書き を木構造(LogicalUnit)にする
# ============================================================

type
  LUKind = enum
    luLine      # 単純な1行
    luForBlock  # 繰り返しブロック(count回) + 本体

  LogicalUnit = ref object
    case kind: LUKind
    of luLine:
      text: string
    of luForBlock:
      count: string
      body: seq[LogicalUnit]

const
  markStart     = "ここから"
  markEndPrefix = "ここまでを"
  markEndSuffix = "回繰り返す"
  markAsPrefix  = "以下を"
  markAsSuffix  = "回繰り返す"
  bulletMark    = "・"

proc extractCount(s, startMark, endMark: string): string =
  ## "ここまでを10回繰り返す" から "10" を取り出す
  let a = s.find(startMark) + startMark.len
  let b = s.find(endMark, a)
  result = s[a ..< b]

proc groupLines(lines: seq[string]): seq[LogicalUnit] =
  var i = 0
  while i < lines.len:
    let line = lines[i]
    if line == markStart:
      # ここから 〜 ここまでを##回繰り返す
      inc i
      var bodyLines: seq[string] = @[]
      while i < lines.len and not lines[i].startsWith(markEndPrefix):
        bodyLines.add(lines[i])
        inc i
      let count = extractCount(lines[i], markEndPrefix, markEndSuffix)
      inc i
      result.add(LogicalUnit(kind: luForBlock, count: count,
                              body: groupLines(bodyLines)))
    elif line.startsWith(markAsPrefix) and line.endsWith(markAsSuffix):
      # 以下を##回繰り返す 〜 ・箇条書き ...
      let count = extractCount(line, markAsPrefix, markAsSuffix)
      inc i
      var bodyLines: seq[string] = @[]
      while i < lines.len and lines[i].startsWith(bulletMark):
        bodyLines.add(lines[i][bulletMark.len ..^ 1].strip())
        inc i
      result.add(LogicalUnit(kind: luForBlock, count: count,
                              body: groupLines(bodyLines)))
    else:
      result.add(LogicalUnit(kind: luLine, text: line))
      inc i

# ============================================================
# 3. Stmt(AST)定義
# ============================================================

type
  StmtKind = enum
    skAssign     # target = expr
    skAddAssign  # target += expr
    skVarDecl    # var target = expr  ("Xを5とする")
    skLetDecl    # let target = expr  ("定数Xを5とする")
    skIncrement  # inc(target)
    skDecrement  # dec(target)
    skIf         # if/elif チェーン
    skForBlock   # for ループ

  IfBranch = object
    subj, cond: string        # 条件: subj == cond ("" は補完待ち)
    body: seq[Stmt]

  Stmt = ref object
    case kind: StmtKind
    of skAssign, skAddAssign, skVarDecl, skLetDecl:
      target, expr: string    # target=="" は目的語省略(補完待ち)
    of skIncrement, skDecrement:
      tgt: string
    of skIf:
      branches: seq[IfBranch]
    of skForBlock:
      loopVar, count: string
      body: seq[Stmt]

# ============================================================
# 4. 行パース: 1行の文字列 → 値(まだ省略部分は "" のまま)
# ============================================================

proc normalizeExpr(s: string): string =
  ## 演算子の全角→半角変換など
  result = s.replace("×", "*").replace("÷", "/")
            .replace("＋", "+").replace("－", "-").strip()

proc parseAssignPart(actionRaw: string): tuple[target, expr: string] =
  ## "Cを5にする" / "4にする"(目的語省略) を解析する
  var s = actionRaw
  doAssert s.endsWith("にする"), "「にする」で終わらない文です: " & actionRaw
  s = s[0 ..< s.len - "にする".len]
  let idx = s.rfind("を")
  if idx >= 0:
    result.target = s[0 ..< idx]
    result.expr = normalizeExpr(s[idx + "を".len .. ^1])
  else:
    result.target = ""              # 目的語省略 → 後で補完
    result.expr = normalizeExpr(s)

proc parseIfLine(line: string): tuple[subj, cond, target, expr: string] =
  ## "もしBが2なら4にする" / "3ならCを5にする" を解析する
  var s = line
  var subj = ""
  if s.startsWith("もし"):
    s = s["もし".len .. ^1]
    let gaIdx = s.rfind("が")
    subj = s[0 ..< gaIdx]
    s = s[gaIdx + "が".len .. ^1]
  let naraIdx = s.rfind("なら")
  let cond = s[0 ..< naraIdx]         # 主語省略時はここが値だけになる
  let action = s[naraIdx + "なら".len .. ^1]
  let (target, expr) = parseAssignPart(action)
  result = (subj, cond, target, expr)

proc replaceLoopCounter(expr, loopVar: string): string =
  if loopVar.len == 0: expr
  else: expr.replace("ループ回数", loopVar)

proc isIfLine(s: string): bool = s.contains("なら")
proc isFullIf(s: string): bool = s.startsWith("もし")

proc parseSimpleLine(line, loopVar: string): Stmt =
  ## if文以外の1行を Stmt に変換する。
  ## loopVar が空でなければ式中の「ループ回数」をループ変数名に置換する。
  if line.endsWith("を足す"):
    var s = line[0 ..< line.len - "を足す".len]
    let niIdx = s.rfind("に")
    let target = if niIdx >= 0: s[0 ..< niIdx] else: ""
    let exprPart = if niIdx >= 0: s[niIdx + "に".len .. ^1] else: s
    let expr = replaceLoopCounter(normalizeExpr(exprPart), loopVar)
    Stmt(kind: skAddAssign, target: target, expr: expr)
  elif line.endsWith("を増やす"):
    Stmt(kind: skIncrement, tgt: line[0 ..< line.len - "を増やす".len])
  elif line.endsWith("を減少させる"):
    Stmt(kind: skDecrement, tgt: line[0 ..< line.len - "を減少させる".len])
  elif line.endsWith("にする"):
    let (target, expr) = parseAssignPart(line)
    Stmt(kind: skAssign, target: target, expr: replaceLoopCounter(expr, loopVar))
  elif line.startsWith("定数") and line.endsWith("とする"):
    # "定数Aを5とする" → let A = 5
    var s = line["定数".len ..< line.len - "とする".len]
    let idx = s.rfind("を")
    doAssert idx >= 0, "「を」が見つかりません: " & line
    let target = s[0 ..< idx]
    let expr = replaceLoopCounter(normalizeExpr(s[idx + "を".len .. ^1]), loopVar)
    Stmt(kind: skLetDecl, target: target, expr: expr)
  elif line.endsWith("とする"):
    # "Bを5とする" → var B = 5
    var s = line[0 ..< line.len - "とする".len]
    let idx = s.rfind("を")
    doAssert idx >= 0, "「を」が見つかりません: " & line
    let target = s[0 ..< idx]
    let expr = replaceLoopCounter(normalizeExpr(s[idx + "を".len .. ^1]), loopVar)
    Stmt(kind: skVarDecl, target: target, expr: expr)
  else:
    raise newException(ValueError, "未知の構文です: " & line)

# ============================================================
# 5. LogicalUnit列 → Stmt列
#    「もし〜なら」の連続行を if/elif チェーンにまとめる
# ============================================================

var loopCounter = 0  ## ここから/以下ブロックごとに増える連番(LOOP_TIMES_N)

proc buildStmts(units: seq[LogicalUnit], loopVar: string): seq[Stmt] =
  var i = 0
  while i < units.len:
    let u = units[i]
    case u.kind
    of luForBlock:
      inc loopCounter
      let newLoopVar = "LOOP_TIMES_" & $loopCounter
      let bodyStmts = buildStmts(u.body, newLoopVar)
      result.add(Stmt(kind: skForBlock, loopVar: newLoopVar,
                       count: u.count, body: bodyStmts))
      inc i
    of luLine:
      if isIfLine(u.text) and isFullIf(u.text):
        # "もし〜なら" から始まる if/elif チェーンをまとめて消費する
        var branches: seq[IfBranch] = @[]
        let (subj, cond, target, expr) = parseIfLine(u.text)
        branches.add(IfBranch(subj: subj, cond: cond,
                       body: @[Stmt(kind: skAssign, target: target,
                                    expr: replaceLoopCounter(expr, loopVar))]))
        inc i
        while i < units.len and units[i].kind == luLine and
              isIfLine(units[i].text) and not isFullIf(units[i].text):
          let (subj2, cond2, target2, expr2) = parseIfLine(units[i].text)
          branches.add(IfBranch(subj: subj2, cond: cond2,
                         body: @[Stmt(kind: skAssign, target: target2,
                                      expr: replaceLoopCounter(expr2, loopVar))]))
          inc i
        result.add(Stmt(kind: skIf, branches: branches))
      else:
        result.add(parseSimpleLine(u.text, loopVar))
        inc i

# ============================================================
# 6. 省略補完パス
#    「主語・目的語が省略されていたら直前に参照した変数を対象にする」
#    lastVar を左から右・上から下へ流しながら埋めていく
# ============================================================

proc resolveOmissions(stmts: seq[Stmt], lastVar: var string) =
  for s in stmts:
    case s.kind
    of skAssign, skAddAssign, skVarDecl, skLetDecl:
      if s.target.len == 0:
        s.target = lastVar
      else:
        lastVar = s.target
    of skIncrement, skDecrement:
      if s.tgt.len == 0:
        s.tgt = lastVar
      else:
        lastVar = s.tgt
    of skIf:
      for br in s.branches.mitems:
        if br.subj.len == 0:
          br.subj = lastVar
        else:
          lastVar = br.subj
        resolveOmissions(br.body, lastVar)
    of skForBlock:
      resolveOmissions(s.body, lastVar)

# ============================================================
# 7. コード生成
# ============================================================

proc indentStr(n: int): string = "  ".repeat(n)

proc genStmts(stmts: seq[Stmt], indent: int): seq[string]

proc genStmt(s: Stmt, indent: int): seq[string] =
  case s.kind
  of skAssign:
    result = @[indentStr(indent) & s.target & "=" & s.expr]
  of skAddAssign:
    result = @[indentStr(indent) & s.target & "+=" & s.expr]
  of skVarDecl:
    result = @[indentStr(indent) & "var " & s.target & "=" & s.expr]
  of skLetDecl:
    result = @[indentStr(indent) & "let " & s.target & "=" & s.expr]
  of skIncrement:
    result = @[indentStr(indent) & "inc(" & s.tgt & ")"]
  of skDecrement:
    result = @[indentStr(indent) & "dec(" & s.tgt & ")"]
  of skIf:
    result = @[]
    for idx, br in s.branches:
      let kw = if idx == 0: "if " else: "elif "
      result.add(indentStr(indent) & kw & br.subj & "==" & br.cond & ":")
      result.add(genStmts(br.body, indent + 1))
  of skForBlock:
    result = @[indentStr(indent) & "for " & s.loopVar & " in 1 .. " &
               s.count & ":"]
    result.add(genStmts(s.body, indent + 1))

proc genStmts(stmts: seq[Stmt], indent: int): seq[string] =
  for s in stmts:
    result.add(genStmt(s, indent))

# ============================================================
# 8. 変数収集パス
#    「Xを5とする」「定数Xを5とする」で明示的に宣言された変数は除き、
#    式中も含めて使用されている変数を集め、暗黙のものは var X=0 で
#    宣言を補う(forループ変数はforが自動宣言するので対象外)。
# ============================================================

proc extractIdents(s: string): seq[string] =
  ## 式・条件文字列から識別子を抜き出す。
  ## 半角英字に加え、日本語の変数名(漢字・ひらがな・カタカナ等の非ASCII文字)にも対応する。
  ## 演算子(+ - * / 全角含む正規化後の記号)や数字だけの部分は識別子として拾わない。
  let runes = s.toRunes()
  proc isIdentStart(r: Rune): bool =
    let c = r.int32
    if c < 128: chr(c) in {'a'..'z', 'A'..'Z', '_'}
    else: true   # ASCII以外(日本語など)は識別子の一部とみなす
  proc isIdentCont(r: Rune): bool =
    let c = r.int32
    if c < 128: chr(c) in {'a'..'z', 'A'..'Z', '0'..'9', '_'}
    else: true
  var i = 0
  while i < runes.len:
    if isIdentStart(runes[i]):
      var j = i + 1
      while j < runes.len and isIdentCont(runes[j]):
        inc j
      result.add($runes[i ..< j])
      i = j
    else:
      inc i

proc collectVars(stmts: seq[Stmt], declared, loopVars: var HashSet[string],
                  used: var seq[string]) =
  for s in stmts:
    case s.kind
    of skAssign, skAddAssign:
      if s.target.len > 0: used.add(s.target)
      used.add(extractIdents(s.expr))
    of skVarDecl, skLetDecl:
      declared.incl(s.target)
      used.add(extractIdents(s.expr))
    of skIncrement, skDecrement:
      used.add(s.tgt)
    of skIf:
      for br in s.branches:
        if br.subj.len > 0: used.add(br.subj)
        used.add(extractIdents(br.cond))
        collectVars(br.body, declared, loopVars, used)
    of skForBlock:
      loopVars.incl(s.loopVar)
      used.add(extractIdents(s.count))
      collectVars(s.body, declared, loopVars, used)

# ============================================================
# 9. トップレベル: japanimソース文字列 → Nimソース文字列
# ============================================================

proc compileJapanim*(src: string): string =
  loopCounter = 0
  let lines = readLogicalLines(src)
  let units = groupLines(lines)
  let stmts = buildStmts(units, loopVar = "")
  var lastVar = ""
  resolveOmissions(stmts, lastVar)

  # 明示的な宣言(let/var)が無い変数は、先頭で var X=0 として宣言する
  var declared = initHashSet[string]()
  var loopVars = initHashSet[string]()
  var used: seq[string] = @[]
  collectVars(stmts, declared, loopVars, used)

  var seen = initHashSet[string]()
  var declLines: seq[string] = @[]
  for name in used:
    if name notin declared and name notin loopVars and name notin seen:
      seen.incl(name)
      declLines.add("var " & name & "=0")

  let outLines = genStmts(stmts, 0)
  result = (declLines & outLines).join("\n")

# ============================================================
# 動作確認用エントリポイント
# ============================================================

when isMainModule:
  const sample = """
定数Aを5とする
Bを5とする
一時退避レジスタをBにする
なまをををつうじにににする
Fを3にする
もしBが2なら4にする
3ならCを5にする
ここから
Dにループ回数を足す
EをD+E×2にする
ここまでを10回繰り返す
以下を10回繰り返す
・Fを増やす
・Gを減少させる
・Bに2を足す
以下を30回繰り返す
・Fを増やす
・3×B+3を足す
"""
  echo compileJapanim(sample)
