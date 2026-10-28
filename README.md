# 리눅스용 카카오톡 Flatpak

리눅스에서 카카오톡을 쉽게 실행할 수 있도록 만든 프로젝트입니다.

## 설치 및 실행

1. [Releases](https://github.com/bmcyver/kakaotalk-flatpak/releases/latest)에서 `KakaoTalk.flatpak`을 다운로드합니다.
2. 다운로드한 파일이 있는 디렉터리에서 다음 명령어를 실행합니다.

   ```sh
   flatpak install KakaoTalk.flatpak
   ```

   현재 사용자에게만 설치하려면 `--user` 옵션을 추가합니다.

   ```sh
   flatpak install --user KakaoTalk.flatpak
   ```

3. 설치가 끝나면 카카오톡을 실행합니다. (첫 실행에는 최대 3분이 소요됩니다)

## 참고 사항

- Ubuntu 26.04.1에서 테스트했으며, 다른 환경에서의 동작은 보장하지 않습니다.
- 설치 후 `설정 → 화면 → 화면 배율`과 `설정 → 채팅 → 다운로드 폴더`를 환경에 맞게 조정하는 것을 권장합니다.
- 샌드박싱을 위해 기본 파일 접근 권한은 `xdg-download`로 제한되어 있습니다. 필요한 경우 아래 방법으로 권한을 추가하세요.

### 파일 접근 권한 추가

예를 들어 현재 사용자의 홈 디렉터리에 접근할 수 있도록 하려면 다음 명령을 실행합니다.

```sh
flatpak override --filesystem=home com.kakao.KakaoTalk
```

특정 디렉터리만 허용하려면 `home` 대신 절대 경로를 지정합니다.

```sh
flatpak override --filesystem=/path/dir com.kakao.KakaoTalk
```

## 면책 조항

이 프로젝트는 Kakao Corp.이 만들거나 인가하지 않았습니다. 사용 중 발생하는 모든 책임은 사용자에게 있습니다.
