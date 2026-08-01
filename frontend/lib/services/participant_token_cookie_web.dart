// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _participantTokenCookieName = 'gurumeet_participant_token';
const _participantTokenLocalStorageKey = 'gurumeet_participant_token';
const _participantTokenCookieMaxAgeSeconds = 60 * 60 * 24 * 365;

String? readParticipantTokenLocalStorage() {
  final value = html.window.localStorage[_participantTokenLocalStorageKey];
  return value == null || value.isEmpty ? null : value;
}

void writeParticipantTokenLocalStorage(String token) {
  html.window.localStorage[_participantTokenLocalStorageKey] = token;
}

String? readParticipantTokenCookie() {
  final cookieHeader = html.document.cookie;
  if (cookieHeader == null || cookieHeader.isEmpty) {
    return null;
  }

  for (final rawCookie in cookieHeader.split(';')) {
    final separatorIndex = rawCookie.indexOf('=');
    if (separatorIndex == -1) {
      continue;
    }
    final name = rawCookie.substring(0, separatorIndex).trim();
    if (name != _participantTokenCookieName) {
      continue;
    }
    final value = rawCookie.substring(separatorIndex + 1).trim();
    final decoded = Uri.decodeComponent(value);
    return decoded.isEmpty ? null : decoded;
  }
  return null;
}

void writeParticipantTokenCookie(String token) {
  final encoded = Uri.encodeComponent(token);
  html.document.cookie =
      '$_participantTokenCookieName=$encoded; '
      'path=/; '
      'max-age=$_participantTokenCookieMaxAgeSeconds; '
      'SameSite=Lax';
}
