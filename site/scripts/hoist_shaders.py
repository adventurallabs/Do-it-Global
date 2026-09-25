"""One-off refactor: turn <shaderMaterial .../> JSX children into useShader() calls.

For each block: parse its JSX attributes, build a params object literal, insert
`const <name> = useShader({...})` before the enclosing component's `return (`,
and give the parent <points>/<mesh> a `material={<name>}` prop.
"""
import re
import sys


def read_value(s, i):
    """s[i] == '{' — return (expr, index after matching '}'), template-aware."""
    assert s[i] == '{'
    depth = 0
    j = i
    stack = []  # 'b' brace, 't' template
    while j < len(s):
        c = s[j]
        top = stack[-1] if stack else None
        if top == 't':
            if c == '\\':
                j += 2
                continue
            if c == '`':
                stack.pop()
            elif c == '$' and s[j + 1] == '{':
                stack.append('b')
                j += 2
                continue
        else:
            if c == '`':
                stack.append('t')
            elif c == '{':
                stack.append('b')
            elif c == '}':
                stack.pop()
                if not stack:
                    return s[i + 1 : j], j + 1
        j += 1
    raise ValueError('unbalanced')


def parse_block(s, start):
    i = start + len('<shaderMaterial')
    props = []
    while True:
        while s[i].isspace():
            i += 1
        if s.startswith('/>', i):
            return props, i + 2
        m = re.match(r'[A-Za-z]+', s[i:])
        name = m.group(0)
        i += len(name)
        if s[i] == '=':
            expr, i = read_value(s, i + 1)
            props.append((name, expr.strip()))
        else:
            props.append((name, 'true'))


def transform(path, names):
    s = open(path, encoding='utf8').read()
    k = 0
    while '<shaderMaterial' in s:
        start = s.index('<shaderMaterial')
        props, end = parse_block(s, start)
        props = [(n, e) for n, e in props if n != 'ref']
        name = names[k]
        k += 1
        body = ',\n    '.join(f'{n}: {e}' for n, e in props)
        # remove block (and the whitespace line it sat on)
        line_start = s.rfind('\n', 0, start) + 1
        if s[line_start:start].strip() == '':
            start = line_start
            if s[end] == '\n':
                end += 1
        s = s[:start] + s[end:]
        # parent tag: nearest previous <points or <mesh
        p = max(s.rfind('<points', 0, start), s.rfind('<mesh', 0, start))
        tag_end = p + (len('<points') if s.startswith('<points', p) else len('<mesh'))
        s = s[:tag_end] + f' material={{{name}}}' + s[tag_end:]
        # self-close the parent if it is now empty: <mesh ...>\n  <geometry/>\n</mesh> stays valid.
        r = s.rfind('\n  return (', 0, p)
        decl = f'\n  const {name} = useShader({{\n    {body},\n  }})\n'
        s = s[:r] + decl + s[r:]
    if 'useShader' in s and "from './useShader'" not in s and "useShader'" not in s.split('\n', 30)[-1]:
        rel = './useShader' if '/common/' in path.replace('\\', '/') else '../common/useShader'
        s = s.replace("import * as THREE from 'three'", f"import * as THREE from 'three'\nimport {{ useShader }} from '{rel}'", 1)
    open(path, 'w', encoding='utf8').write(s)
    print(path, k)


if __name__ == '__main__':
    path, *names = sys.argv[1:]
    transform(path, names)
