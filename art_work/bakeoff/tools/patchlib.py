import re, io
def load(p): return io.open(p, encoding="utf-8").read()
def save(p, s): io.open(p, "w", encoding="utf-8", newline="\n").write(s)
def block(s, name, body):
    pat = re.compile(r"const %s = rows\(\{.*?\n\}\)" % name, re.S)
    assert pat.search(s), name
    return pat.sub(lambda m: "const %s = rows({\n%s\n})" % (name, body.strip("\n")), s, count=1)
def setrow(s, name, y, runs):
    """replace (or add) one row inside a rows() block; runs is the text after 'y: '"""
    pat = re.compile(r"(const %s = rows\(\{)(.*?)(\n\}\))" % name, re.S)
    m = pat.search(s); assert m, name
    body = m.group(2)
    rp = re.compile(r"\n  %d:\s*\[\[.*?\]\],(?=\n|$)" % y)
    line = "\n  %d: %s," % (y, runs)
    if rp.search(body): body = rp.sub(lambda _: line, body, count=1)
    else:
        # insert in order
        lines = body.split("\n"); out=[]; done=False
        for ln in lines:
            mm = re.match(r"\s*(\d+):", ln)
            if mm and not done and int(mm.group(1)) > y:
                out.append(line.strip("\n")); done=True
            out.append(ln)
        if not done: out.append(line.strip("\n"))
        body = "\n".join(out)
    return s[:m.start()] + m.group(1) + body + m.group(3) + s[m.end():]
def delrow(s, name, y):
    pat = re.compile(r"(const %s = rows\(\{)(.*?)(\n\}\))" % name, re.S)
    m = pat.search(s); assert m, name
    body = re.sub(r"\n  %d:\s*\[\[.*?\]\],(?=\n|$)" % y, "", m.group(2), count=1)
    return s[:m.start()] + m.group(1) + body + m.group(3) + s[m.end():]
def rep(s, a, b):
    assert a in s, a[:50]
    return s.replace(a, b)
