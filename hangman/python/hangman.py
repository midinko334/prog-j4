import sys
import os
import random
import defword

CHARTYPES = 64
LIFE = 7

def getChar():
    if sys.platform == "win32":
        import msvcrt
        return msvcrt.getch().decode("utf-8", errors="replace")
    else:
        import tty, termios
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        try:
            tty.setraw(fd)
            ch = sys.stdin.read(1)
        finally:
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
        return ch

def hangman(words: list[str], life: int):
    input_life = life
    sel = random.randint(0, len(words) - 1)
    word = words[sel]
    wlen = len(word)

    used = []
    is_pafe = True
    flag = -1       # -1:first input, 0:not included, 1:included, 2:already used
    used.append(' ')

    while True:
        os.system("cls" if sys.platform == "win32" else "clear")

        for ch in word:
            if any(u == ch or (u.lower() == ch.lower() and ch.isalpha()) for u in used):
                print(ch, end="")
            else:
                print("-", end="")
        print("\n")

        print("Using letter:", ", ".join(used[1:]))

        if flag == -1:
            print()
        elif flag == 1:
            print(f"{ans} is included")
        elif flag == 2:
            print(f"{ans} is already used")
        elif flag == 0:
            print(f"{ans} is not included")

        print(f"Input alphabet({life} life remain): ", end="", flush=True)
        ans = getChar()
        print()

        if ans in (' ', '\n', '\r'):
            continue

        if ans in used:
            flag = 2
        else:
            used.append(ans)
            if any(ans.lower() == ch.lower() for ch in word):
                flag = 1
            else:
                flag = 0
                life -= 1
                is_pafe = False

        if life < 1:
            os.system("cls" if sys.platform == "win32" else "clear")
            print(f"Failure (answer: {word})")
            break

        if all(
            any(u.lower() == ch.lower() for u in used)
            for ch in word
        ):
            os.system("cls" if sys.platform == "win32" else "clear")
            if is_pafe:
                print(f"PERFECT!!!! (answer: {word})")
            else:
                print(f"Success!! (answer: {word})")
                print(f"{life} life remain")
            break

    print("retry?(y/N):")
    retry = input().strip()
    if retry.lower() == 'y':
        hangman(words, input_life)


def loadfile(filename: str) -> list[str] | None:
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
    except FileNotFoundError:
        return None

    if not content.strip():
        return None

    words = []
    for line in content.splitlines():
        line = line.strip()
        if not line:
            continue

        q1 = line.find('"')
        if q1 != -1:
            q2 = line.find('"', q1 + 1)
            if q2 != -1:
                words.append(line[q1 + 1:q2])
                continue

        for token in line.split():
            if any(c.isalpha() for c in token):
                words.append(token)
                break

    return words if words else None


def main():

    random.seed()

    print("Select Gamemode")
    print("- 0 Default Words")
    print("- 1 Custom Words (need words file)")

    try:
        mode = int(input())
    except ValueError:
        print("Invalid")
        return

    mode_changed = False

    if mode == 1:
        filename = input("Input wordfile name: ").strip()
        words = loadfile(filename)

        if words is None:
            reason = "Can't open the file" if not os.path.exists(filename) else "Your file is empty"
            ans = input(f"{reason}. Will you use default words?(Y/n): ").strip()
            if ans.lower() == 'n':
                print("Program Finished")
                return
            mode_changed = True
        else:
            hangman(words, LIFE)

    if mode == 0 or mode_changed:
        print("Select Difficulty")
        print("- 0 Normal(6-35 letter)")
        print("- 1 Easy(3-10 letter)")

        try:
            diff = int(input())
        except ValueError:
            print("Invalid")
            return

        if diff == 0:
            hangman(defword.Defword, LIFE)
        elif diff == 1:
            hangman(defword.Easword, LIFE + 4)
        else:
            print("Invalid")

    elif mode != 1:
        print("Invalid")

    print("bye")


if __name__ == "__main__":
    main()
