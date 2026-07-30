import re
import unicodedata


_SPACE_PATTERN = re.compile(r"\s+")


def normalize_location_query(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).strip().lower()
    normalized = _SPACE_PATTERN.sub("", normalized)
    return katakana_to_hiragana(normalized)


def katakana_to_hiragana(value: str) -> str:
    characters = []
    for character in value:
        codepoint = ord(character)
        if 0x30A1 <= codepoint <= 0x30F6:
            characters.append(chr(codepoint - 0x60))
        else:
            characters.append(character)
    return "".join(characters)
