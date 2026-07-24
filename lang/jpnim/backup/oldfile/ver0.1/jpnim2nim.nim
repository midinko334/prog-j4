## japanim.nim
## ----------------------------------------------------------------
## 日本語DSL「japanim」を Nim ソースコードへトランスコンパイルする。
##
## パイプライン:
##   1. 行の読み込み
##   2. グルーピング : 「ここから〜ここまでを##回繰り返す」(for)
##                      「ここから〜ここまでを{条件}になるまで繰り返す」(while-until)
##                      「ここから〜ここまでを{条件}の間繰り返す」(while-during)
##                      「以下を...繰り返す」+「・」箇条書き(上記3種の箇条書き版)
##                      「もし〜なら」(処理省略)+「・」箇条書き(if複数処理)
##                      をひとつのブロックにまとめる
##   3. 行パース     : 各行をキーワード・助詞で分解する
##   4. Stmt構築     : 「もし〜なら」の連続行/箇条書きブロックを if/elif チェーンにまとめる
##   5. 省略補完     : 主語・目的語省略時に「直前に参照した変数」で埋める
##   6. コード生成   : Stmt木からNimソースを出力する
##
## 条件式の比較演算子(未満/以上/以下/より大きい/超)はif文・while文で
## 共通の parseComparison ヘルパーを使い回す。
## ----------------------------------------------------------------

import std/[strutils, sets]
import std/unicode except strip

# ============================================================
# 1. 行の読み込み
# ============================================================

proc readLogicalLines(src: string): seq[tuple[lineNo: int, text: string]] =
  var n = 0
  for rawLine in src.splitLines():
    let line = rawLine.strip()
    if line.len > 0:
      inc n
      result.add((lineNo: n, text: line))

# ============================================================
# 警告機構・分割ヘルパー(グルーピング・行パースの両方から使うため先に定義する)
# ============================================================

var warnings*: seq[string] = @[]  ## compileJapanim実行ごとにリセットされる警告一覧

proc addWarning(lineNo: int, original: string, tokens: seq[string]) =
  warnings.add($lineNo & "行目の「" & original & "」は「" & tokens.join("/") &
               "」、と読み取りました")

proc rfindSplit(s, sep: string): tuple[before, after: string, found, ambiguous: bool] =
  ## sepの最後の出現位置で s を分割する。
  ## sepがsに2回以上出現していれば ambiguous=true(どこで区切るか曖昧だった)
  let idx = s.rfind(sep)
  if idx < 0:
    return (s, "", false, false)
  result = (s[0 ..< idx], s[idx + sep.len .. ^1], true, s.count(sep) > 1)

proc parseComparison(s: string): tuple[op, value: string] =
  ## if文・while文で共通の比較演算子解析。
  ## "D未満"→("<","D")  "D以上"→(">=","D")  "D以下"→("<=","D")
  ## "Dより大きい"→(">","D")  "D超"→(">","D")  それ以外は等価("==",s)とみなす
  if s.endsWith("未満"):
    ("<", s[0 ..< s.len - "未満".len])
  elif s.endsWith("以上"):
    (">=", s[0 ..< s.len - "以上".len])
  elif s.endsWith("以下"):
    ("<=", s[0 ..< s.len - "以下".len])
  elif s.endsWith("より大きい"):
    (">", s[0 ..< s.len - "より大きい".len])
  elif s.endsWith("超"):
    (">", s[0 ..< s.len - "超".len])
  else:
    ("==", s)

# ============================================================
# 2. グルーピング
#    ここから〜ここまで / 以下＋箇条書き / もし〜なら(複数処理) を
#    木構造(LogicalUnit)にする
# ============================================================

type
  LUKind = enum
    luLine       # 単純な1行
    luForBlock   # 繰り返しブロック(count回) + 本体
    luWhileBlock # 繰り返しブロック(while条件) + 本体
    luIfBlock    # 「もし〜なら」(処理省略) + ・箇条書きの複数処理本体

  LogicalUnit = ref object
    body: seq[LogicalUnit]  # luForBlock/luWhileBlock/luIfBlockで使用(luLineでは空のまま)
    case kind: LUKind
    of luLine:
      lineNo: int
      text: string
    of luForBlock:
      count: string
    of luWhileBlock:
      cond: string     # 比較式("L<D"や"フラグ==3"など、正規化済み)
      negate: bool     # true: while not (cond)  ("〜になるまで繰り返す")
                        # false: while (cond)     ("〜の間繰り返す")
    of luIfBlock:
      ifLineNo: int
      ifText: string

const
  markStart         = "ここから"
  markEndPrefix     = "ここまでを"
  markAsPrefix      = "以下を"
  suffixFor         = "回繰り返す"
  suffixWhileUntil  = "になるまで繰り返す"    # 「〜になるまで繰り返す」→ while not (cond)
  suffixWhileDuringBare = "間繰り返す"        # 「〜間繰り返す」/「〜の間繰り返す」→ while (cond)
                                             # 「の」は省略可能として扱う
  bulletMark        = "・"

proc endsWithWhileDuring(s: string): bool =
  ## 「の間繰り返す」「間繰り返す」(の省略形)のどちらにもマッチする
  s.endsWith(suffixWhileDuringBare)

proc extractMiddle(s, startMark, endMark: string): string =
  ## "ここまでを10回繰り返す" から "10" を取り出す
  let a = s.find(startMark) + startMark.len
  let b = s.rfind(endMark)
  result = s[a ..< b]

proc classifyBlockHeader(s, startMark: string): tuple[kind, mid: string] =
  ## startMark〜末尾の表現から、for/while_until/while_during の種別とその中身を判定する
  if s.endsWith(suffixFor):
    ("for", extractMiddle(s, startMark, suffixFor))
  elif s.endsWith(suffixWhileUntil):
    ("while_until", extractMiddle(s, startMark, suffixWhileUntil))
  elif endsWithWhileDuring(s):
    # 「の間繰り返す」「間繰り返す」どちらの形でも、末尾の「間繰り返す」を
    # 切り落としてから、余った「の」があれば追加で取り除く
    var mid = extractMiddle(s, startMark, suffixWhileDuringBare)
    if mid.endsWith("の"):
      mid = mid[0 ..< mid.len - "の".len]
    ("while_during", mid)
  else:
    raise newException(ValueError, "不明な繰り返し表現です: " & s)

proc parseCondExpr(mid: string): tuple[condExpr: string, ambiguous: bool] =
  ## "LがD未満" → ("L<D", false) のように、while条件文字列を比較式へ変換する
  let (before, after, found, amb) = rfindSplit(mid, "が")
  doAssert found, "「が」が見つかりません: " & mid
  let (op, value) = parseComparison(after)
  result = (before & op & value, amb)

proc isBareIfLine(line: string): bool =
  ## "もしEが2なら"のように、「なら」で終わり後続処理が同じ行に無い(処理省略)行かどうか
  if not line.contains("なら"): return false
  let (_, after, found, _) = rfindSplit(line, "なら")
  found and after.len == 0

proc groupLines(lines: seq[tuple[lineNo: int, text: string]]): seq[LogicalUnit] =
  var i = 0
  while i < lines.len:
    let line = lines[i].text
    let lineNo = lines[i].lineNo
    if line == markStart:
      # ここから 〜 ここまでを##回繰り返す / ここまでを{条件}になるまで(の間)繰り返す
      inc i
      var bodyLines: seq[tuple[lineNo: int, text: string]] = @[]
      while i < lines.len and not lines[i].text.startsWith(markEndPrefix):
        bodyLines.add(lines[i])
        inc i
      let headerLine = lines[i].text
      let headerLineNo = lines[i].lineNo
      inc i
      let (kind, mid) = classifyBlockHeader(headerLine, markEndPrefix)
      if kind == "for":
        result.add(LogicalUnit(kind: luForBlock, count: mid,
                                body: groupLines(bodyLines)))
      else:
        let (condExpr, amb) = parseCondExpr(mid)
        if amb: addWarning(headerLineNo, headerLine, @[mid])
        result.add(LogicalUnit(kind: luWhileBlock, cond: condExpr,
                                negate: kind == "while_until",
                                body: groupLines(bodyLines)))
    elif line.startsWith(markAsPrefix) and
         (line.endsWith(suffixFor) or line.endsWith(suffixWhileUntil) or
          endsWithWhileDuring(line)):
      # 以下を##回繰り返す / 以下を{条件}になるまで(の間)繰り返す 〜 ・箇条書き ...
      let (kind, mid) = classifyBlockHeader(line, markAsPrefix)
      inc i
      var bodyLines: seq[tuple[lineNo: int, text: string]] = @[]
      while i < lines.len and lines[i].text.startsWith(bulletMark):
        bodyLines.add((lineNo: lines[i].lineNo,
                        text: lines[i].text[bulletMark.len ..^ 1].strip()))
        inc i
      if kind == "for":
        result.add(LogicalUnit(kind: luForBlock, count: mid,
                                body: groupLines(bodyLines)))
      else:
        let (condExpr, amb) = parseCondExpr(mid)
        if amb: addWarning(lineNo, line, @[mid])
        result.add(LogicalUnit(kind: luWhileBlock, cond: condExpr,
                                negate: kind == "while_until",
                                body: groupLines(bodyLines)))
    elif isBareIfLine(line):
      # もし〜なら(処理省略) 〜 ・箇条書きの複数処理本体
      inc i
      var bodyLines: seq[tuple[lineNo: int, text: string]] = @[]
      while i < lines.len and lines[i].text.startsWith(bulletMark):
        bodyLines.add((lineNo: lines[i].lineNo,
                        text: lines[i].text[bulletMark.len ..^ 1].strip()))
        inc i
      result.add(LogicalUnit(kind: luIfBlock, ifLineNo: lineNo, ifText: line,
                              body: groupLines(bodyLines)))
    else:
      result.add(LogicalUnit(kind: luLine, lineNo: lineNo, text: line))
      inc i

# ============================================================
# 3. Stmt(AST)定義
# ============================================================

type
  StmtKind = enum
    skAssign      # target = expr
    skAddAssign   # target += expr
    skVarDecl     # var target = expr  ("Xを5とする")
    skLetDecl     # let target = expr  ("定数Xを5とする")
    skIncrement   # inc(target)
    skDecrement   # dec(target)
    skIf          # if/elif チェーン
    skForBlock    # for ループ
    skWhileBlock  # while ループ

  IfBranch = object
    subj, op, value: string   # 条件: subj op value ("" は補完待ち)
    body: seq[Stmt]

  Stmt = ref object
    body: seq[Stmt]  # skForBlock/skWhileBlockで使用(それ以外では空のまま)
    case kind: StmtKind
    of skAssign, skAddAssign, skVarDecl, skLetDecl:
      target, expr: string    # target=="" は目的語省略(補完待ち)
    of skIncrement, skDecrement:
      tgt: string
    of skIf:
      branches: seq[IfBranch]
    of skForBlock:
      loopVar, count: string
    of skWhileBlock:
      cond: string             # 補完不要なので既に組み立て済みの比較式を持つ
      negate: bool

# ============================================================
# 4. 行パース: 1行の文字列 → 値(まだ省略部分は "" のまま)
#    曖昧警告: 助詞(区切り文字列)が対象範囲内に複数回出現する場合、
#    「最後の出現位置」を採用した上で、読み取り結果を警告として記録する。
# ============================================================

proc normalizeExpr(s: string): string =
  ## 演算子の全角→半角変換など
  result = s.replace("×", "*").replace("÷", "/")
            .replace("＋", "+").replace("－", "-").strip()

proc parseAssignPart(actionRaw: string):
    tuple[target, expr: string, tokens: seq[string], ambiguous: bool] =
  ## "Cを5にする" / "4にする"(目的語省略) を解析する
  var s = actionRaw
  doAssert s.endsWith("にする"), "「にする」で終わらない文です: " & actionRaw
  s = s[0 ..< s.len - "にする".len]
  let (before, after, found, amb) = rfindSplit(s, "を")
  if found:
    result.target = before
    result.expr = normalizeExpr(after)
    result.tokens = @[before, "を", after, "に", "する"]
    result.ambiguous = amb
  else:
    result.target = ""              # 目的語省略 → 後で補完
    result.expr = normalizeExpr(s)
    result.tokens = @[s, "に", "する"]
    result.ambiguous = false

proc parseIfConditionPrefix(line: string):
    tuple[subj, condPart, rest: string, tokens: seq[string], ambiguous: bool] =
  ## "もしBが2なら4にする" / "3ならCを5にする" / "もしEが2なら" 共通の前半解析。
  ## condPart: 「なら」の直前(比較演算子付きの可能性あり)
  ## rest    : 「なら」の直後(処理省略行なら空文字列)
  var s = line
  var subj = ""
  var tokens: seq[string] = @[]
  var ambiguous = false
  if s.startsWith("もし"):
    tokens.add("もし")
    s = s["もし".len .. ^1]
    let (before, after, found, amb) = rfindSplit(s, "が")
    doAssert found, "「が」が見つかりません: " & line
    subj = before
    s = after
    tokens.add(subj)
    tokens.add("が")
    if amb: ambiguous = true
  let (condPart, rest, foundNara, ambNara) = rfindSplit(s, "なら")
  doAssert foundNara, "「なら」が見つかりません: " & line
  if ambNara: ambiguous = true
  result = (subj, condPart, rest, tokens, ambiguous)

proc parseIfLine(line: string):
    tuple[subj, op, value, target, expr: string, tokens: seq[string], ambiguous: bool] =
  ## "もしBが2なら4にする" / "3ならCを5にする" を解析する(同じ行に処理あり)
  let (subj, condPart, actionPart, tokens0, amb0) = parseIfConditionPrefix(line)
  let (op, value) = parseComparison(condPart)
  var tokens = tokens0
  tokens.add(value)
  tokens.add(op)
  tokens.add("なら")
  var ambiguous = amb0
  let (target, expr, actionTokens, actionAmb) = parseAssignPart(actionPart)
  tokens.add(actionTokens)
  if actionAmb: ambiguous = true
  result = (subj, op, value, target, expr, tokens, ambiguous)

proc parseIfCondOnly(line: string):
    tuple[subj, op, value: string, tokens: seq[string], ambiguous: bool] =
  ## "もしEが2なら" / "5未満なら" を解析する(処理は別行の箇条書きに続く)
  let (subj, condPart, rest, tokens0, amb0) = parseIfConditionPrefix(line)
  doAssert rest.len == 0, "「なら」の後に処理が続いています(箇条書きと混在): " & line
  let (op, value) = parseComparison(condPart)
  var tokens = tokens0
  tokens.add(value)
  tokens.add(op)
  tokens.add("なら")
  result = (subj, op, value, tokens, amb0)

proc replaceLoopCounter(expr, loopVar: string): string =
  if loopVar.len == 0: expr
  else: expr.replace("ループ回数", loopVar)

proc isIfLine(s: string): bool = s.contains("なら")
proc isFullIf(s: string): bool = s.startsWith("もし")

const
  incrementSuffixes = ["を増やす", "を増加させる"]
  decrementSuffixes = ["を減少させる", "を減らす"]

proc matchSuffix(s: string, suffixes: openArray[string]): string =
  ## 複数の表記ゆれ語尾のうち、実際に一致したものを返す(無ければ "")
  for suf in suffixes:
    if s.endsWith(suf): return suf
  ""

proc parseSimpleLine(line: string, lineNo: int, loopVar: string): Stmt =
  ## if文以外の1行を Stmt に変換する。
  ## loopVar が空でなければ式中の「ループ回数」をループ変数名に置換する。
  let incSuf = matchSuffix(line, incrementSuffixes)
  let decSuf = matchSuffix(line, decrementSuffixes)
  if line.endsWith("を足す"):
    var s = line[0 ..< line.len - "を足す".len]
    let (before, after, found, amb) = rfindSplit(s, "に")
    if found and after.len > 0:
      # "Xに Yを 足す" : 対象Xも値Yも揃っている通常形
      if amb: addWarning(lineNo, line, @[before, "に", after, "を", "足す"])
      let expr = replaceLoopCounter(normalizeExpr(after), loopVar)
      Stmt(kind: skAddAssign, target: before, expr: expr)
    else:
      # 「に」が無い、または区切った結果が空(＝変数名自体に「に」を含むだけ)
      # → 対象(主語)省略。全体を足す値として扱い、対象は直近の主語で補完する。
      # 「に」が全く無い場合は曖昧さが無いため警告しない。
      # 「に」はあるが区切ると空expr(＝変数名の一部だった)場合のみ警告する。
      if found:
        addWarning(lineNo, line, @[s, "を", "足す"])
      let expr = replaceLoopCounter(normalizeExpr(s), loopVar)
      Stmt(kind: skAddAssign, target: "", expr: expr)
  elif line.endsWith("に足す"):
    # "Xに足す" : 対象Xのみ指定され、足す値が省略されている
    # → 値は直近の目的語(最後に使われた式)で補完する。
    # 末尾の「に」を rfindSplit で切り出すことで、他パターンと同様
    # 「target自体に『に』がもう1つ以上含まれる場合のみ」曖昧警告を出す。
    let s = line[0 ..< line.len - "足す".len]   # 末尾が "に" で終わる文字列
    let (before, _, _, amb) = rfindSplit(s, "に")
    let target = before
    if amb: addWarning(lineNo, line, @[target, "に", "足す"])
    Stmt(kind: skAddAssign, target: target, expr: "")
  elif incSuf.len > 0:
    # "Xを増やす" / "Xを増加させる"(表記ゆれ)
    Stmt(kind: skIncrement, tgt: line[0 ..< line.len - incSuf.len])
  elif decSuf.len > 0:
    # "Xを減少させる" / "Xを減らす"(表記ゆれ)
    Stmt(kind: skDecrement, tgt: line[0 ..< line.len - decSuf.len])
  elif line.endsWith("にする"):
    let (target, expr, tokens, ambiguous) = parseAssignPart(line)
    if ambiguous: addWarning(lineNo, line, tokens)
    Stmt(kind: skAssign, target: target, expr: replaceLoopCounter(expr, loopVar))
  elif line.startsWith("定数") and line.endsWith("とする"):
    # "定数Aを5とする" → let A = 5
    var s = line["定数".len ..< line.len - "とする".len]
    let (before, after, found, amb) = rfindSplit(s, "を")
    doAssert found, "「を」が見つかりません: " & line
    let target = before
    let tokens = @["定数", before, "を", after, "と", "する"]
    if amb: addWarning(lineNo, line, tokens)
    let expr = replaceLoopCounter(normalizeExpr(after), loopVar)
    Stmt(kind: skLetDecl, target: target, expr: expr)
  elif line.endsWith("とする"):
    # "Bを5とする" → var B = 5
    var s = line[0 ..< line.len - "とする".len]
    let (before, after, found, amb) = rfindSplit(s, "を")
    doAssert found, "「を」が見つかりません: " & line
    let target = before
    let tokens = @[before, "を", after, "と", "する"]
    if amb: addWarning(lineNo, line, tokens)
    let expr = replaceLoopCounter(normalizeExpr(after), loopVar)
    Stmt(kind: skVarDecl, target: target, expr: expr)
  else:
    raise newException(ValueError, "未知の構文です: " & line)

# ============================================================
# 5. LogicalUnit列 → Stmt列
#    「もし〜なら」の連続行/箇条書きブロックを if/elif チェーンにまとめる
# ============================================================

var loopCounter = 0  ## ここから/以下ブロックごとに増える連番(LOOP_TIMES_N)

proc buildStmts(units: seq[LogicalUnit], loopVar: string): seq[Stmt]

proc unitIsIfLine(u: LogicalUnit): bool =
  ## if/elifチェーンの一部になり得るLogicalUnitかどうか
  case u.kind
  of luLine: isIfLine(u.text)
  of luIfBlock: true
  else: false

proc unitIsFullIf(u: LogicalUnit): bool =
  ## 「もし」で始まる(＝チェーンの先頭になれる)かどうか
  case u.kind
  of luLine: isFullIf(u.text)
  of luIfBlock: isFullIf(u.ifText)
  else: false

proc unitToIfBranch(u: LogicalUnit, loopVar: string): IfBranch =
  ## luLine(if文1行) / luIfBlock(if文+箇条書き複数処理) をIfBranchに変換する
  case u.kind
  of luLine:
    let (subj, op, value, target, expr, tokens, ambiguous) = parseIfLine(u.text)
    if ambiguous: addWarning(u.lineNo, u.text, tokens)
    IfBranch(subj: subj, op: op, value: value,
             body: @[Stmt(kind: skAssign, target: target,
                          expr: replaceLoopCounter(expr, loopVar))])
  of luIfBlock:
    let (subj, op, value, tokens, ambiguous) = parseIfCondOnly(u.ifText)
    if ambiguous: addWarning(u.ifLineNo, u.ifText, tokens)
    IfBranch(subj: subj, op: op, value: value,
             body: buildStmts(u.body, loopVar))
  else:
    raise newException(ValueError, "if文として扱えないLogicalUnitです")

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
    of luWhileBlock:
      # while条件は組み立て時点で主語が確定しているため省略補完は不要
      let bodyStmts = buildStmts(u.body, loopVar)
      result.add(Stmt(kind: skWhileBlock, cond: u.cond, negate: u.negate,
                       body: bodyStmts))
      inc i
    of luLine, luIfBlock:
      if unitIsIfLine(u) and unitIsFullIf(u):
        # "もし〜なら" から始まる if/elif チェーンをまとめて消費する
        # (1行完結型・箇条書き複数処理型のどちらでも、また混在していても連結する)
        var branches: seq[IfBranch] = @[unitToIfBranch(u, loopVar)]
        inc i
        while i < units.len and unitIsIfLine(units[i]) and not unitIsFullIf(units[i]):
          branches.add(unitToIfBranch(units[i], loopVar))
          inc i
        result.add(Stmt(kind: skIf, branches: branches))
      elif u.kind == luIfBlock:
        # "もし" を伴わない省略elif的な書き方が単独(先頭)で出てきた場合も
        # そこから新たなif/elifチェーンとして扱う
        var branches: seq[IfBranch] = @[unitToIfBranch(u, loopVar)]
        inc i
        while i < units.len and unitIsIfLine(units[i]) and not unitIsFullIf(units[i]):
          branches.add(unitToIfBranch(units[i], loopVar))
          inc i
        result.add(Stmt(kind: skIf, branches: branches))
      else:
        result.add(parseSimpleLine(u.text, u.lineNo, loopVar))
        inc i

# ============================================================
# 6. 省略補完パス
#    「主語(対象)が省略されていたら直前に参照した変数」
#    「目的語(値/式)が省略されていたら直前に使われた式」で埋める。
#    lastVar(直近の主語) / lastExpr(直近の目的語) を
#    左から右・上から下へ流しながら埋めていく
# ============================================================

proc resolveOmissions(stmts: seq[Stmt], lastVar, lastExpr: var string) =
  for s in stmts:
    case s.kind
    of skAssign, skAddAssign, skVarDecl, skLetDecl:
      if s.target.len == 0:
        s.target = lastVar          # 主語(対象)省略 → 直近の主語で補完
      else:
        lastVar = s.target
      if s.expr.len == 0:
        s.expr = lastExpr           # 目的語(値)省略 → 直近の目的語で補完
      else:
        lastExpr = s.expr
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
        resolveOmissions(br.body, lastVar, lastExpr)
    of skForBlock, skWhileBlock:
      resolveOmissions(s.body, lastVar, lastExpr)

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
      result.add(indentStr(indent) & kw & br.subj & br.op & br.value & ":")
      result.add(genStmts(br.body, indent + 1))
  of skForBlock:
    result = @[indentStr(indent) & "for " & s.loopVar & " in 1 .. " &
               s.count & ":"]
    result.add(genStmts(s.body, indent + 1))
  of skWhileBlock:
    let condStr = if s.negate: "not (" & s.cond & ")" else: s.cond
    result = @[indentStr(indent) & "while " & condStr & ":"]
    result.add(genStmts(s.body, indent + 1))

proc genStmts(stmts: seq[Stmt], indent: int): seq[string] =
  for s in stmts:
    result.add(genStmt(s, indent))
  if result.len == 0:
    # 箇条書き本体が空(記述ミス等)でも構文的に有効なNimコードにしておく
    result = @[indentStr(indent) & "discard"]

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
        used.add(extractIdents(br.value))
        collectVars(br.body, declared, loopVars, used)
    of skForBlock:
      loopVars.incl(s.loopVar)
      used.add(extractIdents(s.count))
      collectVars(s.body, declared, loopVars, used)
    of skWhileBlock:
      used.add(extractIdents(s.cond))
      collectVars(s.body, declared, loopVars, used)

# ============================================================
# 9. トップレベル: japanimソース文字列 → Nimソース文字列
# ============================================================

proc compileJapanim*(src: string): string =
  loopCounter = 0
  warnings = @[]
  let lines = readLogicalLines(src)
  let units = groupLines(lines)
  let stmts = buildStmts(units, loopVar = "")
  var lastVar = ""
  var lastExpr = ""
  resolveOmissions(stmts, lastVar, lastExpr)

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
つうじににを足す
つうじににに足す
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
AにBを足す
つうじににに足す
Cを足す
なまをををにをりににする
Hを10にする
以下をHが3未満になるまで繰り返す
・Hを減らす
Jを5にする
以下をJが0より大きいの間繰り返す
・Jを減らす
Lを5にする
以下をLが0より大きい間繰り返す
・Lを減らす
Kを0にする
ここから
Kを増やす
ここまでをKが3以上になるまで繰り返す
もしFが10以上なら
・Fを減らす
・Gを増加させる
5未満なら
・Gを減らす
"""
  let code = compileJapanim(sample)
  if warnings.len > 0:
    echo "警告:"
    for w in warnings:
      echo w
    echo ""
    echo "出力コード:"
  echo code
