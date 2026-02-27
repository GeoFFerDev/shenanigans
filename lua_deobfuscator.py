#!/usr/bin/env python3
"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Lua Deobfuscator — Security Research Tool
  Supports: MoonSec V2/V3  |  Luraph 14.x  |  Generic Lua
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Usage:
  python lua_deobfuscator.py <script.lua> [options]

Options:
  -o  --output  <file>   Output dump file   (default: dump.txt)
  --json <file>          Also save JSON report
  -v  --verbose          Verbose mode
  --no-color             Disable colored output
  --force-luraph         Skip auto-detect, treat as Luraph
  --force-moonsec        Skip auto-detect, treat as MoonSec

For ethical security research only.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import sys, os, re, json, struct, zlib, base64, string, argparse
from typing import List, Dict, Optional, Tuple, Any
from collections import Counter

# ──────────────────────────────────────────────────────────
# Terminal colours
# ──────────────────────────────────────────────────────────
USE_COLOR = True

def C(code): return f"\033[{code}m" if USE_COLOR else ""
RESET  = lambda: C(0)
CYAN   = lambda s: f"{C(36)}{s}{C(0)}"
GREEN  = lambda s: f"{C(32)}{s}{C(0)}"
YELLOW = lambda s: f"{C(33)}{s}{C(0)}"
RED    = lambda s: f"{C(31)}{s}{C(0)}"
BOLD   = lambda s: f"{C(1)}{s}{C(0)}"
DIM    = lambda s: f"{C(2)}{s}{C(0)}"

def log(msg, level="INFO"):
    icons = {"INFO": CYAN("[*]"), "OK": GREEN("[+]"),
             "WARN": YELLOW("[!]"), "ERR": RED("[-]")}
    print(f"{icons.get(level,'[?]')} {msg}")

SEP  = "─" * 70
SEP2 = "═" * 70

# ──────────────────────────────────────────────────────────
# Obfuscator auto-detection
# ──────────────────────────────────────────────────────────

def detect_obfuscator(src: str) -> str:
    """Returns: 'moonsec_v3', 'moonsec_v2', 'luraph', 'generic'"""
    if re.search(r'This file was protected with MoonSec V3', src):
        return 'moonsec_v3'
    if re.search(r'This file was protected with MoonSec', src):
        return 'moonsec_v2'
    if re.search(r'LURAPH_UNIQUE_(?:UPVALUE_)?ID|luraph', src, re.I):
        return 'luraph'
    # MoonSec V3 heuristic: two large base85 string vars + gsub pattern
    if (re.search(r":gsub\('.\\+'", src) and
            len(re.findall(r"='[^']{10000,}'", src)) >= 2):
        return 'moonsec_v3'
    # Luraph heuristic: heavy decimal escape + IIFE
    if (len(re.findall(r'\\[0-9]{1,3}', src)) > 200 and
            re.search(r'local\s+\w+\s*=\s*\(function\(\)', src)):
        return 'luraph'
    return 'generic'

# ══════════════════════════════════════════════════════════
# ███  MOONSEC V3 ANALYSER  ███
# ══════════════════════════════════════════════════════════

class MoonSecV3Analyser:
    """
    MoonSec V3 static analysis engine.

    Architecture overview
    ─────────────────────
    MoonSec V3 scripts contain:
      • Two large base-85 payload strings (the encoded Lua 5.1 bytecode)
      • A string-constant table (16-char hex-like encoding with rolling XOR)
      • A VM bootstrap / runtime decoder written in obfuscated Lua
      • An import loader using a custom r(key, encoded_str) cipher

    What we can recover statically
    ───────────────────────────────
      1. Both payload fingerprints (size, charset, entropy)
      2. The import table (via r() cipher reversal)
      3. VM constant values (opcode masks, table sizes, …)
      4. String constant table (raw + best-effort decode)
      5. Roblox API surface (pattern matched from VM body)
      6. Anti-analysis markers
    """

    # Known Roblox / Luau API names we watch for
    ROBLOX_APIS = [
        "game","workspace","Players","LocalPlayer","Character","Humanoid",
        "RemoteFunction","RemoteEvent","BindableFunction","BindableEvent",
        "HttpService","TeleportService","MarketplaceService","UserInputService",
        "RunService","ReplicatedStorage","ServerStorage","StarterGui",
        "FireServer","InvokeServer","FireClient","InvokeClient",
        "GetService","WaitForChild","FindFirstChild","FindFirstChildOfClass",
        "LoadString","loadstring","pcall","xpcall","require",
        "Instance.new","Humanoid.WalkSpeed","Humanoid.JumpPower",
        "Humanoid.Health","CharacterAdded","PlayerAdded",
        "GetPlayers","GetChildren","GetDescendants",
        "Vector3","CFrame","Color3","BrickColor",
        "EquipTool","UnequipTool","SelectionBox",
        "Touched","ChildAdded","AncestryChanged",
        "Debris","BodyVelocity","BodyGyro","BodyPosition",
        "SendNotification","SetCore","GetCore",
        "Mouse","Hit","Target","Button1Down",
        "DataStoreService","GetDataStore","SetAsync","GetAsync",
        "HttpGet","HttpPost","RequestAsync",
        "syn","rconsole","getgenv","getsenv","getreg","getupvalues",
        "hookfunction","newcclosure","islclosure","readfile","writefile",
        "getfenv","setfenv","debug","getuserdata",
    ]

    def __init__(self, src: str, verbose: bool = False):
        self.src     = src
        self.verbose = verbose
        self.report: Dict[str, Any] = {}

    # ── public entry point ──────────────────────────────────
    def analyse(self) -> Dict[str, Any]:
        log("Detecting MoonSec V3 structure …")
        self._extract_payloads()
        self._extract_vm_section()
        self._decode_import_table()
        self._extract_string_table()
        self._decode_string_table()
        self._scan_apis()
        self._anti_analysis_check()
        return self.report

    # ── step 1: payload extraction ──────────────────────────
    def _extract_payloads(self):
        payloads = []
        for m in re.finditer(rb"(\w+)='([^']{500,})'", self.src.encode('utf-8','replace')):
            raw  = m.group(2).decode('utf-8', 'replace')
            charset = sorted(set(raw))
            entropy = self._entropy(raw)
            payloads.append({
                "var":     m.group(1).decode(),
                "length":  len(raw),
                "charset": ''.join(charset),
                "charset_size": len(charset),
                "entropy": round(entropy, 3),
                "sample":  raw[:80],
            })
        self.report["payloads"] = payloads
        log(f"Found {len(payloads)} encoded payload(s)", "OK")
        for p in payloads:
            if self.verbose:
                log(f"  {p['var']}: {p['length']:,} chars, "
                    f"charset={p['charset_size']}, entropy={p['entropy']}")

    # ── step 2: isolate VM section ──────────────────────────
    def _extract_vm_section(self):
        raw = self.src.encode('utf-8','replace')
        # Find last payload end, then grab everything after
        last_end = 0
        for m in re.finditer(rb"='[^']{500,}'", raw):
            last_end = m.end()
        self._vm_text = raw[last_end:].decode('utf-8','replace') if last_end else ""
        self.report["vm_section_size"] = len(self._vm_text)
        log(f"VM section: {len(self._vm_text):,} chars after last payload")

    # ── step 3: decode import table (r() cipher) ────────────
    def _decode_import_table(self):
        """
        The r(key, encoded) cipher:
          • First 16 chars of `encoded` are the nibble alphabet (char→0..15)
          • Remaining chars processed in pairs:
              raw_byte = nibble_map[c0]*16 + nibble_map[c1]
              out_byte = (raw_byte + rolling_key) % 256
              rolling_key = (seed + rolling_key)   [no modulo here — Python bignum]
          • output bytes then passed to string.char() via o()
        """
        imports = {}
        r_call  = re.search(r'l\(r\((\d+),\s*"([^"]+)"\)\)', self._vm_text)
        if not r_call:
            self.report["import_table"] = {}
            log("Import table r() call not found", "WARN")
            return

        seed = int(r_call.group(1))
        enc  = r_call.group(2)
        decoded = self._r_decode(seed, enc)
        if decoded is None:
            self.report["import_table"] = {}
            return

        # Parse the binary import structure
        e = 0
        raw_imports = []
        while e < len(decoded):
            if decoded[e] == 5:   # end marker
                break
            entry_type  = decoded[e]; e += 1
            name_len    = decoded[e]; e += 1
            name        = decoded[e:e+name_len]; e += name_len
            key_bytes   = decoded[e:e+8];        e += 8
            try:
                name_s = bytes(name).decode('utf-8','replace')
                key_s  = bytes(key_bytes).decode('utf-8','replace')
                raw_imports.append({"type": entry_type, "name": name_s, "key": key_s})
                imports[key_s] = name_s
            except Exception:
                break

        self.report["import_table"] = imports
        self.report["import_table_raw"] = raw_imports
        log(f"Decoded import table: {len(imports)} entries", "OK")

        # Extract numeric VM constants (type=2 → tonumber applied → numeric masks)
        vm_constants = {}
        for entry in raw_imports:
            if entry["type"] == 2:
                try:
                    vm_constants[entry["key"]] = int(entry["name"])
                except ValueError:
                    pass
        self.report["vm_constants"] = vm_constants
        if self.verbose:
            log(f"  VM numeric constants: {dict(list(vm_constants.items())[:10])}")

    def _r_decode(self, seed: int, enc: str) -> Optional[List[int]]:
        if len(enc) < 16:
            return None
        alpha    = enc[:16]
        nib_map  = {c: i for i, c in enumerate(alpha)}
        result   = []
        rolling  = seed
        i        = 16
        while i + 1 < len(enc):
            c0, c1 = enc[i], enc[i+1]
            n0 = nib_map.get(c0, 0)
            n1 = nib_map.get(c1, 0)
            result.append((n0 * 16 + n1 + rolling) % 256)
            rolling = seed + rolling
            i += 2
        return result

    # ── step 4: extract raw string constant table ───────────
    def _extract_string_table(self):
        m = re.search(r'(\w+)\s*=\s*\{(".*?",?""\s*)\}', self._vm_text, re.DOTALL)
        if not m:
            # fallback: find biggest table assignment
            m = re.search(r'\w+\s*=\s*\{("(?:[^"]*)",?){5,}\}', self._vm_text, re.DOTALL)
        raw_strings = []
        if m:
            raw_strings = re.findall(r'"([^"]*)"', m.group(0))
        self.report["string_table_raw"] = raw_strings
        log(f"String constant table: {len(raw_strings)} entries", "OK")

    # ── step 5: decode string constants (16-char hex+XOR) ──
    def _decode_string_table(self):
        """
        MoonSec V3 encodes string constants with a fixed 16-char nibble alphabet.
        The alphabet ordering is derived from the order characters first appear
        across the whole string table. Rolling XOR key is brute-forced.
        """
        raw = self.report.get("string_table_raw", [])
        if not raw:
            self.report["string_table_decoded"] = []
            return

        combined = "".join(raw)
        # Derive alphabet (first 16 unique chars in order of first appearance)
        seen_chars = []
        for c in combined:
            if c not in seen_chars:
                seen_chars.append(c)
            if len(seen_chars) == 16:
                break

        if len(seen_chars) < 16:
            self.report["string_table_decoded"] = []
            log("Could not derive 16-char alphabet for string table", "WARN")
            return

        nib_map = {c: i for i, c in enumerate(seen_chars)}
        self.report["string_table_alphabet"] = ''.join(seen_chars)

        printable_set = set(range(32, 127))
        best_key, best_ratio = 0, 0.0

        # Test all 256 keys on the combined string
        for key in range(256):
            decoded_bytes = self._hex16_decode(combined, nib_map, key)
            ratio = sum(1 for b in decoded_bytes if b in printable_set) / max(len(decoded_bytes), 1)
            if ratio > best_ratio:
                best_ratio, best_key = ratio, key

        self.report["string_table_key"] = best_key
        self.report["string_table_key_confidence"] = round(best_ratio, 3)
        log(f"String table key={best_key} (confidence={best_ratio:.1%})", "OK")

        decoded_list = []
        for s in raw:
            if not s:
                decoded_list.append("")
                continue
            dec_bytes = self._hex16_decode(s, nib_map, best_key)
            try:
                text = bytes(dec_bytes).decode('utf-8','replace').rstrip('\x00')
            except Exception:
                text = repr(bytes(dec_bytes))
            decoded_list.append(text)

        self.report["string_table_decoded"] = decoded_list

        # Show preview
        if self.verbose:
            for i, s in enumerate(decoded_list[:8]):
                log(f"  str[{i}]: {repr(s[:60])}")

    def _hex16_decode(self, s: str, nib_map: Dict, key: int) -> List[int]:
        result  = []
        rolling = key
        i       = 0
        while i + 1 < len(s):
            n0 = nib_map.get(s[i],   0)
            n1 = nib_map.get(s[i+1], 0)
            bv = (n0 * 16 + n1 + rolling) % 256
            result.append(bv)
            rolling = (key + rolling) % 256   # bounded rolling for string consts
            i += 2
        return result

    # ── step 6: Roblox/Luau API surface scan ───────────────
    def _scan_apis(self):
        hits = {}
        # Scan both VM section and raw payloads (encoded chars still contain substrings)
        scan_target = self.src + self._vm_text
        for api in self.ROBLOX_APIS:
            count = scan_target.count(api)
            if count:
                hits[api] = count
        self.report["api_hits"] = hits
        self.report["suspicious_apis"] = [
            k for k in hits if k in (
                "loadstring","LoadString","syn","rconsole","getgenv",
                "getsenv","hookfunction","newcclosure","HttpGet","HttpPost",
                "RequestAsync","readfile","writefile","getfenv","setfenv",
                "getreg","getupvalues","debug","FireServer","InvokeServer",
            )
        ]
        log(f"API surface: {len(hits)} hits, {len(self.report['suspicious_apis'])} suspicious", "OK")

    # ── step 7: anti-analysis markers ──────────────────────
    def _anti_analysis_check(self):
        markers = []
        patterns = {
            "getfenv/setfenv anti-tamper": r'\bgetfenv\b.*\bsetfenv\b',
            "Obfuscated IIFE chain":       r'\(function\(\)\s*\(function\(\)',
            "Metamethod __call obfuscation": r'__call',
            "Multiple upvalue closures":   r'\bfunction\b.*\bupvalue\b',
            "String.byte decoding loop":   r'string\.byte.*for',
            "pcall error suppression":     r'\bpcall\b.*\bfunction\b.*\bend\b',
            "xpcall with handler":         r'\bxpcall\b',
            "getfenv environment hijack":  r'getfenv\s*\(\s*\d+\s*\)',
            "debug.getinfo probe":         r'debug\.getinfo',
            "Anti-decompiler NOP sleds":   r'\(function\(\)\s*end\)\s*\(\)',
        }
        for name, pat in patterns.items():
            if re.search(pat, self.src + self._vm_text, re.DOTALL):
                markers.append(name)
        self.report["anti_analysis_markers"] = markers
        if markers:
            log(f"Anti-analysis: {len(markers)} marker(s) detected", "WARN")

    # ── utility ─────────────────────────────────────────────
    @staticmethod
    def _entropy(s: str) -> float:
        if not s: return 0.0
        freq = Counter(s)
        n    = len(s)
        import math
        return -sum((c/n)*math.log2(c/n) for c in freq.values())


# ══════════════════════════════════════════════════════════
# ███  LURAPH 14.x ANALYSER  ███
# ══════════════════════════════════════════════════════════

LURAPH_OPCODES = {
    0:"MOVE",1:"LOADK",2:"LOADBOOL",3:"LOADNIL",4:"GETUPVAL",5:"GETGLOBAL",
    6:"GETTABLE",7:"SETGLOBAL",8:"SETUPVAL",9:"SETTABLE",10:"NEWTABLE",
    11:"SELF",12:"ADD",13:"SUB",14:"MUL",15:"DIV",16:"MOD",17:"POW",
    18:"UNM",19:"NOT",20:"LEN",21:"CONCAT",22:"JMP",23:"EQ",24:"LT",
    25:"LE",26:"TEST",27:"TESTSET",28:"CALL",29:"TAILCALL",30:"RETURN",
    31:"FORLOOP",32:"FORPREP",33:"TFORLOOP",34:"SETLIST",35:"CLOSE",
    36:"CLOSURE",37:"VARARG",50:"LNEWCLOSURE",51:"LLOADKX",
    52:"LSETGLOBAL2",53:"LGETGLOBAL2",54:"LCONCAT2",55:"LJMP2",
}

class LuraphAnalyser:
    def __init__(self, src: str, verbose: bool = False):
        self.src     = src
        self.verbose = verbose
        self.report: Dict[str, Any] = {}

    def analyse(self) -> Dict[str, Any]:
        log("Detecting Luraph 14.x structure …")
        self._fingerprint()
        self._extract_strings()
        self._find_vm_loop()
        self._extract_blobs()
        self._decode_blob()
        self._lift_instructions()
        self._extract_globals()
        self._opcode_freq()
        return self.report

    def _fingerprint(self):
        flags = []
        if re.search(r'LURAPH_UNIQUE', self.src):         flags.append("Luraph unique-ID marker")
        if re.search(r'local\s+\w+=\(function\(\)', self.src): flags.append("IIFE outer wrapper")
        if len(re.findall(r'\\[0-9]{1,3}', self.src)) > 50:  flags.append("Heavy decimal escape")
        if re.search(r'__index.*__newindex', self.src, re.S):  flags.append("Metatable dispatch")
        self.report["fingerprint"] = flags

    def _extract_strings(self):
        def unescape(m): return chr(int(m.group(1)))
        raw = re.findall(r'"((?:[^"\\]|\\.)*)"|\'((?:[^\'\\]|\\.)*)\'' , self.src)
        out = []
        for dq, sq in raw:
            s = re.sub(r'\\(\d{1,3})', unescape, dq or sq)
            s = s.replace('\\n','\n').replace('\\t','\t').replace('\\\\','\\')
            if len(s) > 2:
                out.append(s)
        self.report["strings"] = out

    def _find_vm_loop(self):
        m = re.search(r'(while\s+true\s+do|repeat)(.*?)(end|until\s+false)',
                      self.src, re.DOTALL)
        self.report["vm_loop_body"] = m.group(2)[:4096] if m else None
        if m: log("VM dispatch loop located", "OK")

    def _extract_blobs(self):
        blobs = []
        for enc, pat in [("hex",  re.compile(r'"([0-9a-fA-F]{32,})"')),
                         ("b64",  re.compile(r'"([A-Za-z0-9+/=]{40,})"'))]:
            for m in pat.finditer(self.src):
                blobs.append({"type": enc, "offset": m.start(),
                              "len": len(m.group(1)), "sample": m.group(1)[:64]})
        # decimal escape blob
        m = re.search(r'"((?:\\[0-9]{1,3}){30,})"', self.src)
        if m:
            data = bytes([int(x) for x in re.findall(r'\\(\d{1,3})', m.group(1))])
            blobs.append({"type": "dec_escape", "offset": m.start(),
                          "len": len(data), "sample": data[:32].hex()})
        self.report["blobs"] = blobs

    def _decode_blob(self):
        # Try each blob in order
        xor_key = None
        m = re.search(r',\s*0[xX]([0-9a-fA-F]+)\s*[,)]', self.src)
        if m:
            xor_key = int(m.group(1), 16)
        else:
            m = re.search(r',\s*(\d{1,3})\s*[,)]', self.src)
            if m and 1 <= int(m.group(1)) <= 255:
                xor_key = int(m.group(1))

        self.report["xor_key"] = xor_key
        decoded = None

        for blob in self.report.get("blobs", []):
            try:
                if blob["type"] == "hex":
                    data = bytes.fromhex(blob["sample"] + "")  # sample only
                elif blob["type"] == "dec_escape":
                    data = bytes.fromhex(blob["sample"])
                else:
                    continue

                if xor_key is not None:
                    k = xor_key
                    out = []
                    for b in data:
                        out.append(b ^ k)
                        k = (k + b) & 0xFF
                    data = bytes(out)

                for wbits in (15, -15):
                    try:
                        decoded = zlib.decompress(data, wbits)
                        break
                    except Exception:
                        pass
                if decoded:
                    break
            except Exception:
                continue

        self.report["decoded_blob"] = decoded

    def _lift_instructions(self):
        instrs = []
        blob = self.report.get("decoded_blob")
        if blob:
            for i in range(0, len(blob)-3, 4):
                raw = struct.unpack_from("<I", blob, i)[0]
                op  = raw & 0x3F
                instrs.append({
                    "op": op, "mnemonic": LURAPH_OPCODES.get(op, f"OP_{op}"),
                    "A": (raw>>6)&0xFF, "B": (raw>>23)&0x1FF,
                    "C": (raw>>14)&0x1FF, "sBx": ((raw>>14)&0x3FFFF)-(2**17-1),
                })
        else:
            body = self.report.get("vm_loop_body","") or ""
            for op_str, body_txt in re.findall(
                    r'if\s+\w+\s*==\s*(\d+)\s*then(.*?)(?=if\s+\w+\s*==\s*\d+\s*then|end\s*$)',
                    body, re.DOTALL):
                op = int(op_str)
                instrs.append({
                    "op": op, "mnemonic": LURAPH_OPCODES.get(op, f"OP_{op}"),
                    "handler_excerpt": body_txt.strip()[:150],
                })
        self.report["instructions"] = instrs

    def _extract_globals(self):
        globs = list(dict.fromkeys(re.findall(r"_G\[[\'\"]([^\'\"]+)[\'\"]\]", self.src)))
        self.report["globals"] = globs

    def _opcode_freq(self):
        nums   = [int(n) for n in re.findall(r'\b(\d+)\b', self.src) if int(n) < 64]
        counts = Counter(nums)
        self.report["opcode_freq"] = {
            LURAPH_OPCODES.get(k, f"OP_{k}"): v
            for k, v in sorted(counts.items(), key=lambda x: -x[1])
            if v > 3
        }


# ══════════════════════════════════════════════════════════
# ███  REPORT FORMATTER  ███
# ══════════════════════════════════════════════════════════

class ReportFormatter:
    def __init__(self, obf_type: str, report: Dict):
        self.obf  = obf_type
        self.r    = report

    def render(self) -> str:
        lines = []
        A = lines.append

        A(SEP2)
        A(f"  LUA DEOBFUSCATOR — ANALYSIS REPORT")
        A(f"  Obfuscator: {BOLD(self.obf.upper())}")
        A(SEP2)

        if self.obf == "moonsec_v3":
            self._moonsec_v3(lines)
        elif self.obf == "luraph":
            self._luraph(lines)
        else:
            A("  [Generic analysis — limited output]")

        A(f"\n{SEP2}\n  END OF REPORT\n{SEP2}")
        return "\n".join(lines)

    # ── MoonSec V3 sections ─────────────────────────────────
    def _moonsec_v3(self, L):
        r = self.r

        # Payloads
        L.append(f"\n{SEP}\n{BOLD('[ENCODED PAYLOADS]')}\n{SEP}")
        for p in r.get("payloads", []):
            L.append(f"  Variable : {p['var']}")
            L.append(f"  Length   : {p['length']:,} chars  |  Charset: {p['charset_size']} chars  |  Entropy: {p['entropy']}")
            L.append(f"  Charset  : {p['charset']}")
            L.append(f"  Sample   : {p['sample'][:80]}")
            L.append("")

        # Import table
        L.append(f"\n{SEP}\n{BOLD('[VM IMPORT TABLE  (r-cipher decoded)]')}\n{SEP}")
        imports = r.get("import_table", {})
        vm_k    = r.get("vm_constants", {})
        if imports:
            L.append("  Randomised function handles → real values:")
            for k, v in list(imports.items())[:20]:
                L.append(f"  h['{k}'] = {repr(v)}")
            if len(imports) > 20:
                L.append(f"  … ({len(imports)-20} more)")
        if vm_k:
            L.append(f"\n  VM numeric constants ({len(vm_k)} values):")
            for k, v in list(vm_k.items())[:20]:
                L.append(f"  h['{k}'] = {v}  (0x{v:04X})")

        # Hardcoded Lua 5.1 imports (from p string)
        L.append(f"\n{SEP}\n{BOLD('[HARDCODED RUNTIME IMPORTS  (from p string)]')}\n{SEP}")
        hardcoded = [
            ("bTUkUBCc", "tonumber"),
            ("zSdQznwq", "string.char"),
            ("LezPcjPh", "string.sub"),
            ("VsJbsvVG", "string.byte"),
            ("zgmxRwqQ", "table.concat"),
            ("LFOciAgj", "table.insert"),
        ]
        for key, fn in hardcoded:
            L.append(f"  h['{key}']  →  {GREEN(fn)}")

        # String constant table
        L.append(f"\n{SEP}\n{BOLD('[STRING CONSTANT TABLE]')}\n{SEP}")
        raw_strs = r.get("string_table_raw", [])
        dec_strs = r.get("string_table_decoded", [])
        alpha    = r.get("string_table_alphabet", "")
        key_val  = r.get("string_table_key", "?")
        conf     = r.get("string_table_key_confidence", 0)

        L.append(f"  Encoding scheme : 16-char hex nibble pairs + rolling XOR")
        L.append(f"  Alphabet        : {repr(alpha)}")
        L.append(f"  Recovered key   : {key_val}  (printable ratio: {conf:.1%})")
        L.append(f"  Entries         : {len(raw_strs)}")
        L.append("")

        for i, (raw, dec) in enumerate(zip(raw_strs, dec_strs)):
            if not raw:
                continue
            L.append(f"  [{i:02d}] raw  = {raw[:70]}{'…' if len(raw)>70 else ''}")
            if dec:
                display = dec[:120].replace('\n','↵').replace('\r','')
                printable_ratio = sum(1 for c in dec if c in string.printable) / max(len(dec),1)
                quality = GREEN("✓ DECODED") if printable_ratio > 0.85 else YELLOW("~ partial")
                L.append(f"       dec  = {display}  [{quality}]")
            L.append("")

        # API surface
        L.append(f"\n{SEP}\n{BOLD('[ROBLOX API / GLOBAL SURFACE]')}\n{SEP}")
        hits  = r.get("api_hits", {})
        susps = set(r.get("suspicious_apis", []))
        if hits:
            L.append(f"  {'API name':<30} {'Hits':>5}  {'Flag'}")
            L.append(f"  {'-'*30} {'-'*5}  {'-'*20}")
            for api, cnt in sorted(hits.items(), key=lambda x: -x[1]):
                flag = RED("⚠ EXPLOIT") if api in susps else ""
                L.append(f"  {api:<30} {cnt:>5}  {flag}")
        else:
            L.append("  No known API names detected in static scan.")

        # Suspicious APIs summary
        if susps:
            L.append(f"\n  {RED('Suspicious APIs detected:')}")
            for s in susps:
                L.append(f"  {RED('⚠')} {s}")

        # Anti-analysis
        L.append(f"\n{SEP}\n{BOLD('[ANTI-ANALYSIS MARKERS]')}\n{SEP}")
        markers = r.get("anti_analysis_markers", [])
        if markers:
            for m in markers:
                L.append(f"  {YELLOW('⚠')} {m}")
        else:
            L.append("  None detected.")

        # Countermeasure guidance
        L.append(f"\n{SEP}\n{BOLD('[COUNTERMEASURE GUIDANCE]')}\n{SEP}")
        guide = self._build_countermeasures(r)
        for line in guide:
            L.append(line)

        # Notes
        L.append(f"\n{SEP}\n{BOLD('[DECOMPILATION NOTES]')}\n{SEP}")
        L.append("  MoonSec V3 encodes Lua 5.1 bytecode in two base-85 payload strings.")
        L.append("  Full decompilation requires one of:")
        L.append("   1. Runtime instrumentation: hook string.char / table.concat in a")
        L.append("      Lua 5.1 sandbox to capture the decoded payload at runtime.")
        L.append("   2. Port the MoonSec VM bootstrap to Python (complex, per-build).")
        L.append("   3. luac -u / unluac on the recovered Lua 5.1 bytecode chunks.")
        L.append("  The string table key found above gives partial constant recovery.")

    # ── Luraph sections ────────────────────────────────────
    def _luraph(self, L):
        r = self.r

        L.append(f"\n{SEP}\n{BOLD('[FINGERPRINT]')}\n{SEP}")
        for f in r.get("fingerprint", []):
            L.append(f"  • {f}")

        L.append(f"\n{SEP}\n{BOLD('[STRING CONSTANTS]')}\n{SEP}")
        seen = set()
        for s in r.get("strings", []):
            if s not in seen:
                seen.add(s)
                L.append(f"  {repr(s[:100])}")

        L.append(f"\n{SEP}\n{BOLD('[GLOBAL REFERENCES]')}\n{SEP}")
        for g in r.get("globals", []):
            L.append(f"  _G['{g}']")

        L.append(f"\n{SEP}\n{BOLD('[LIFTED VM INSTRUCTIONS]')}\n{SEP}")
        instrs = r.get("instructions", [])
        L.append(f"  Total: {len(instrs)} instructions")
        for i, ins in enumerate(instrs[:200]):
            if "handler_excerpt" in ins:
                L.append(f"  [{i:04d}] {ins['mnemonic']:<14} → {ins['handler_excerpt'][:60]}")
            else:
                L.append(f"  [{i:04d}] {ins['mnemonic']:<14} A={ins['A']:3d} B={ins['B']:3d} "
                         f"C={ins['C']:3d} sBx={ins['sBx']:6d}")

        L.append(f"\n{SEP}\n{BOLD('[OPCODE FREQUENCY]')}\n{SEP}")
        for op, cnt in list(r.get("opcode_freq",{}).items())[:15]:
            bar = "█" * min(cnt//50, 40)
            L.append(f"  {op:<14} {cnt:>6}×  {bar}")

        blob = r.get("decoded_blob")
        if blob:
            L.append(f"\n{SEP}\n{BOLD('[DECODED PAYLOAD  ({} bytes)]'.format(len(blob)))}\n{SEP}")
            try:
                text = blob.decode('utf-8','replace')
                if re.search(r'\b(local|function|return|end)\b', text):
                    L.append("  >> Decoded blob is Lua source! <<")
                    L.append(text[:4096])
                else:
                    L.append(f"  Hex: {blob[:64].hex()}")
            except Exception:
                L.append(f"  Hex: {blob[:64].hex()}")

        L.append(f"\n{SEP}\n{BOLD('[XOR KEY]')}\n{SEP}")
        xk = r.get("xor_key")
        L.append(f"  Key: {xk} (0x{xk:02X})" if xk is not None else "  Not found")

    # ── countermeasure guidance builder ────────────────────
    def _build_countermeasures(self, r: Dict) -> List[str]:
        lines = []
        susps = r.get("suspicious_apis", [])

        if "FireServer" in susps or "InvokeServer" in susps:
            lines += [
                "  Remote abuse detected:",
                "  → Monitor outgoing FireServer/InvokeServer calls with a hook.",
                "  → Validate all RemoteEvent/RemoteFunction arguments server-side.",
                "  → Add rate-limiting and type checking on all remotes.",
            ]
        if "loadstring" in susps or "LoadString" in susps:
            lines += [
                "  Dynamic code execution (loadstring) detected:",
                "  → Disable loadstring in the Roblox game settings if unused.",
                "  → Sandbox environments that accept arbitrary strings.",
            ]
        if any(x in susps for x in ["syn","rconsole","getgenv","hookfunction","newcclosure"]):
            lines += [
                "  Exploit executor API detected (syn/rconsole/getgenv):",
                "  → These APIs only exist in exploit environments (Synapse X, etc.).",
                "  → Add server-side sanity checks: verify character state, speed, position.",
                "  → Implement anti-cheat heartbeat checks for movement/health anomalies.",
            ]
        if "HttpGet" in susps or "HttpPost" in susps or "RequestAsync" in susps:
            lines += [
                "  HTTP exfiltration/C2 detected:",
                "  → Review all outbound HTTP calls on the server.",
                "  → Block unauthorized domains via Roblox HTTP whitelist.",
            ]
        if "readfile" in susps or "writefile" in susps:
            lines += [
                "  Filesystem access detected (readfile/writefile):",
                "  → These run on the client only via an executor.",
                "  → Does not affect server, but signals a client-side cheat.",
            ]
        if not lines:
            lines = ["  No specific countermeasures triggered.  Review API hits manually."]
        return lines


# ══════════════════════════════════════════════════════════
# ███  MAIN  ███
# ══════════════════════════════════════════════════════════

def main():
    global USE_COLOR

    p = argparse.ArgumentParser(
        description="Lua Security Research Deobfuscator — MoonSec V3 & Luraph 14.x",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="For ethical security research only."
    )
    p.add_argument("input",         help="Obfuscated .lua script")
    p.add_argument("-o","--output", default="dump.txt", help="Output file (default: dump.txt)")
    p.add_argument("--json",        default="",         help="Also export JSON report")
    p.add_argument("-v","--verbose",action="store_true",help="Verbose output")
    p.add_argument("--no-color",    action="store_true",help="Disable colour")
    p.add_argument("--force-luraph",  action="store_true")
    p.add_argument("--force-moonsec", action="store_true")
    args = p.parse_args()

    if args.no_color:
        USE_COLOR = False

    if not os.path.isfile(args.input):
        print(RED(f"File not found: {args.input}"))
        sys.exit(1)

    with open(args.input, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()

    print(f"\n{BOLD('━'*60)}")
    print(f"  Lua Deobfuscator  |  {args.input}  ({len(src):,} chars)")
    print(f"{BOLD('━'*60)}\n")

    # Detect
    if args.force_luraph:
        obf = "luraph"
    elif args.force_moonsec:
        obf = "moonsec_v3"
    else:
        obf = detect_obfuscator(src)

    log(f"Detected obfuscator: {BOLD(obf.upper())}", "OK")

    # Analyse
    if obf.startswith("moonsec"):
        analyser = MoonSecV3Analyser(src, args.verbose)
    else:
        analyser = LuraphAnalyser(src, args.verbose)

    report = analyser.analyse()
    report["obfuscator"] = obf
    report["input_file"] = args.input
    report["input_size"] = len(src)

    # Format
    fmt  = ReportFormatter(obf, report)
    dump = fmt.render()

    # Save txt
    with open(args.output, "w", encoding="utf-8") as f:
        # Strip ANSI for file
        clean = re.sub(r'\033\[\d+m', '', dump)
        f.write(clean)
    log(f"Report saved → {args.output}", "OK")

    # Save JSON
    if args.json:
        # Make JSON-safe
        safe = {}
        for k, v in report.items():
            if isinstance(v, (str, int, float, bool, list, dict)):
                safe[k] = v
        # decoded blob → hex
        if "decoded_blob" in safe and isinstance(safe["decoded_blob"], bytes):
            safe["decoded_blob"] = safe["decoded_blob"].hex()
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(safe, f, indent=2, default=str)
        log(f"JSON saved → {args.json}", "OK")

    # Print summary to terminal
    print(f"\n{dump[:6000]}")
    if len(dump) > 6000:
        print(f"\n{DIM('… (truncated in terminal — full report in ' + args.output + ')')}")


if __name__ == "__main__":
    main()
