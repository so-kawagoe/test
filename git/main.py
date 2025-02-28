import random

def number_guessing_game():
    # 1から100までのランダムな数を生成
    target = random.randint(1, 100)
    attempts = 0
    
    print("1から100までの数を当ててください！")
    
    while True:
        try:
            # ユーザーからの入力を受け取る
            guess = int(input("数を入力してください: "))
            attempts += 1
            
            # 数字を比較
            if guess < target:
                print("もっと大きい数字です！")
            elif guess > target:
                print("もっと小さい数字です！")
            else:
                print(f"正解です！{attempts}回で当てることができました！")
                break
                
        except ValueError:
            print("有効な数字を入力してください。")

if __name__ == "__main__":
    number_guessing_game()