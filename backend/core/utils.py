import re


def to_camel(snake_str: str) -> str:
    parts = snake_str.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])


def camelize(data):
    if isinstance(data, dict):
        return {to_camel(k): camelize(v) for k, v in data.items()}
    if isinstance(data, list):
        return [camelize(item) for item in data]
    return data
