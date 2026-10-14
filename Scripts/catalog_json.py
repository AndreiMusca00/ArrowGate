"""Consistent readable JSON: structured levels, compact coordinates, bounded lines."""
import json


def dumps_catalog(value, width=120):
    def compact(item):
        return json.dumps(item, ensure_ascii=False, separators=(',', ':'))

    def small(item):
        if not isinstance(item, dict):
            return not isinstance(item, list)
        return len(item) <= 4 and all(
            not isinstance(v, list) and (not isinstance(v, dict) or
            all(not isinstance(child, (list, dict)) for child in v.values()))
            for v in item.values()
        )

    def render(item, depth):
        indent = '  ' * depth
        child_indent = '  ' * (depth + 1)
        if isinstance(item, dict):
            if not item or small(item):
                return compact(item)
            rows = [child_indent + json.dumps(k, ensure_ascii=False) + ': ' + render(v, depth + 1)
                    for k, v in item.items()]
            return '{\n' + ',\n'.join(rows) + '\n' + indent + '}'
        if isinstance(item, list):
            if not item:
                return '[]'
            if all(small(v) for v in item):
                inline = compact(item)
                if len(inline) + len(child_indent) <= width:
                    return inline
                # Coordinate and target arrays wrap without expanding every x/y pair.
                rows = []
                line = child_indent
                for index, v in enumerate(item):
                    token = compact(v) + (',' if index + 1 < len(item) else '')
                    if len(line) + len(token) > width and line != child_indent:
                        rows.append(line.rstrip())
                        line = child_indent
                    line += token + ' '
                rows.append(line.rstrip())
                return '[\n' + '\n'.join(rows) + '\n' + indent + ']'
            return '[\n' + ',\n'.join(child_indent + render(v, depth + 1) for v in item) + '\n' + indent + ']'
        return compact(item)

    return render(value, 0)
