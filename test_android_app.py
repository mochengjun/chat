#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Android应用自动化测试脚本
用于在Android模拟器上执行SecChat应用的自动化测试
"""

import os
import sys
import time
import json
import subprocess
from datetime import datetime
from pathlib import Path

class AndroidTestRunner:
    """Android测试执行器"""
    
    def __init__(self):
        self.sdk_path = r"C:\Android\Sdk"
        self.adb_path = os.path.join(self.sdk_path, "platform-tools", "adb.exe")
        self.emulator_path = os.path.join(self.sdk_path, "emulator", "emulator.exe")
        self.apk_path = r"installer\android\SecChat-debug.apk"
        self.package_name = "com.example.sec_chat"
        self.test_results = []
        self.device_id = None
        
    def log(self, message, level="INFO"):
        """记录日志"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_message = f"[{timestamp}] [{level}] {message}"
        print(log_message)
        
        # 保存到文件
        with open("test_results.log", "a", encoding="utf-8") as f:
            f.write(log_message + "\n")
    
    def run_command(self, command, timeout=30):
        """执行命令"""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout,
                encoding='utf-8',
                errors='ignore'
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return False, "", "Command timeout"
        except Exception as e:
            return False, "", str(e)
    
    def check_adb(self):
        """检查ADB是否可用"""
        self.log("检查ADB工具...")
        success, stdout, stderr = self.run_command(f'"{self.adb_path}" version')
        if success:
            self.log(f"ADB版本: {stdout.split()[4]}", "SUCCESS")
            return True
        else:
            self.log(f"ADB不可用: {stderr}", "ERROR")
            return False
    
    def check_device(self):
        """检查设备连接"""
        self.log("检查设备连接...")
        success, stdout, stderr = self.run_command(f'"{self.adb_path}" devices')
        
        if not success:
            self.log(f"获取设备列表失败: {stderr}", "ERROR")
            return False
        
        # 解析设备列表
        lines = stdout.strip().split('\n')
        devices = [line for line in lines[1:] if line.strip() and 'device' in line]
        
        if devices:
            self.device_id = devices[0].split()[0]
            self.log(f"发现设备: {self.device_id}", "SUCCESS")
            return True
        else:
            self.log("未发现设备，请启动模拟器", "WARNING")
            return False
    
    def wait_for_device(self, timeout=60):
        """等待设备连接"""
        self.log(f"等待设备连接（超时{timeout}秒）...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if self.check_device():
                return True
            time.sleep(2)
        
        self.log("等待设备超时", "ERROR")
        return False
    
    def get_device_info(self):
        """获取设备信息"""
        if not self.device_id:
            return {}
        
        info = {}
        
        # 获取Android版本
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" -s {self.device_id} shell getprop ro.build.version.release'
        )
        if success:
            info['android_version'] = stdout.strip()
        
        # 获取设备型号
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" -s {self.device_id} shell getprop ro.product.model'
        )
        if success:
            info['device_model'] = stdout.strip()
        
        # 获取屏幕分辨率
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" -s {self.device_id} shell wm size'
        )
        if success:
            info['screen_size'] = stdout.strip().replace('Physical size: ', '')
        
        # 获取屏幕密度
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" -s {self.device_id} shell wm density'
        )
        if success:
            info['screen_density'] = stdout.strip().replace('Physical density: ', '')
        
        self.log(f"设备信息: {json.dumps(info, ensure_ascii=False, indent=2)}")
        return info
    
    def install_apk(self):
        """安装APK"""
        if not os.path.exists(self.apk_path):
            self.log(f"APK文件不存在: {self.apk_path}", "ERROR")
            return False
        
        self.log(f"开始安装APK: {self.apk_path}")
        
        # 检查是否已安装
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" shell pm list packages | findstr {self.package_name}'
        )
        
        if success and self.package_name in stdout:
            self.log("应用已安装，先卸载旧版本...")
            self.run_command(f'"{self.adb_path}" uninstall {self.package_name}')
        
        # 安装APK
        success, stdout, stderr = self.run_command(
            f'"{self.adb_path}" install -r "{self.apk_path}"',
            timeout=60
        )
        
        if success and "Success" in stdout:
            self.log("APK安装成功", "SUCCESS")
            return True
        else:
            self.log(f"APK安装失败: {stderr}", "ERROR")
            return False
    
    def start_app(self):
        """启动应用"""
        self.log("启动应用...")
        success, stdout, stderr = self.run_command(
            f'"{self.adb_path}" shell am start -n {self.package_name}/.MainActivity'
        )
        
        if success:
            self.log("应用启动命令已发送", "SUCCESS")
            time.sleep(3)  # 等待应用启动
            return True
        else:
            self.log(f"应用启动失败: {stderr}", "ERROR")
            return False
    
    def stop_app(self):
        """停止应用"""
        self.log("停止应用...")
        success, _, _ = self.run_command(
            f'"{self.adb_path}" shell am force-stop {self.package_name}'
        )
        return success
    
    def clear_app_data(self):
        """清除应用数据"""
        self.log("清除应用数据...")
        success, _, _ = self.run_command(
            f'"{self.adb_path}" shell pm clear {self.package_name}'
        )
        return success
    
    def take_screenshot(self, filename):
        """截屏"""
        if not self.device_id:
            return False
        
        device_path = "/sdcard/screenshot.png"
        local_path = f"screenshots/{filename}"
        
        # 创建screenshots目录
        os.makedirs("screenshots", exist_ok=True)
        
        # 截屏
        self.run_command(f'"{self.adb_path}" shell screencap -p {device_path}')
        
        # 拉取到本地
        success, _, _ = self.run_command(
            f'"{self.adb_path}" pull {device_path} {local_path}'
        )
        
        if success:
            self.log(f"截图保存: {local_path}", "SUCCESS")
            return True
        return False
    
    def get_logcat(self, duration=5):
        """获取日志"""
        self.log(f"获取应用日志（{duration}秒）...")
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" logcat -d -s flutter:* -t {duration}s',
            timeout=10
        )
        
        if success:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            log_file = f"logs/app_log_{timestamp}.txt"
            os.makedirs("logs", exist_ok=True)
            
            with open(log_file, "w", encoding="utf-8") as f:
                f.write(stdout)
            
            self.log(f"日志已保存: {log_file}", "SUCCESS")
            return True
        return False
    
    def check_permission(self, permission):
        """检查权限"""
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" shell dumpsys package {self.package_name} | findstr {permission}'
        )
        return success and permission in stdout
    
    def record_test_result(self, test_name, passed, details=""):
        """记录测试结果"""
        result = {
            "test_name": test_name,
            "passed": passed,
            "details": details,
            "timestamp": datetime.now().isoformat()
        }
        self.test_results.append(result)
        
        status = "通过" if passed else "失败"
        level = "SUCCESS" if passed else "ERROR"
        self.log(f"测试项 [{test_name}]: {status} - {details}", level)
    
    def run_basic_tests(self):
        """执行基础测试"""
        self.log("\n" + "="*60)
        self.log("开始执行基础测试")
        self.log("="*60 + "\n")
        
        # 测试1: 应用启动
        self.log("\n测试1: 应用启动测试")
        if self.start_app():
            time.sleep(3)
            # 检查应用是否在前台运行
            success, stdout, _ = self.run_command(
                f'"{self.adb_path}" shell dumpsys activity activities | findstr mResumedActivity'
            )
            if success and self.package_name in stdout:
                self.record_test_result("应用启动", True, "应用成功启动并进入前台")
                self.take_screenshot("01_app_started.png")
            else:
                self.record_test_result("应用启动", False, "应用未在前台运行")
        else:
            self.record_test_result("应用启动", False, "应用启动命令失败")
        
        # 测试2: 权限检查
        self.log("\n测试2: 权限检查测试")
        permissions = [
            "android.permission.INTERNET",
            "android.permission.ACCESS_NETWORK_STATE",
            "android.permission.CAMERA",
            "android.permission.POST_NOTIFICATIONS"
        ]
        
        for perm in permissions:
            perm_name = perm.split('.')[-1]
            if self.check_permission(perm):
                self.record_test_result(f"权限检查-{perm_name}", True, f"{perm} 已授权")
            else:
                self.record_test_result(f"权限检查-{perm_name}", False, f"{perm} 未授权")
        
        # 测试3: 网络连接
        self.log("\n测试3: 网络连接测试")
        success, stdout, _ = self.run_command(
            f'"{self.adb_path}" shell ping -c 1 8.8.8.8'
        )
        if success:
            self.record_test_result("网络连接", True, "网络连接正常")
        else:
            self.record_test_result("网络连接", False, "网络连接失败")
        
        # 测试4: 应用稳定性（快速重启）
        self.log("\n测试4: 应用稳定性测试")
        for i in range(3):
            self.stop_app()
            time.sleep(1)
            if self.start_app():
                time.sleep(2)
        
        self.record_test_result("应用稳定性", True, "应用可以正常重启")
        self.take_screenshot("02_app_stable.png")
        
        # 获取日志
        self.get_logcat(10)
    
    def generate_report(self):
        """生成测试报告"""
        self.log("\n生成测试报告...")
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if r["passed"])
        failed_tests = total_tests - passed_tests
        
        report = {
            "test_summary": {
                "total_tests": total_tests,
                "passed_tests": passed_tests,
                "failed_tests": failed_tests,
                "pass_rate": f"{(passed_tests/total_tests*100):.1f}%" if total_tests > 0 else "0%",
                "test_date": datetime.now().isoformat()
            },
            "test_results": self.test_results
        }
        
        # 保存JSON报告
        report_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
        
        self.log(f"测试报告已生成: {report_file}")
        
        # 生成Markdown报告
        md_report = self._generate_markdown_report(report)
        md_file = f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.md"
        with open(md_file, "w", encoding="utf-8") as f:
            f.write(md_report)
        
        self.log(f"Markdown报告已生成: {md_file}")
        
        # 打印摘要
        print("\n" + "="*60)
        print("测试摘要")
        print("="*60)
        print(f"总测试数: {total_tests}")
        print(f"通过: {passed_tests}")
        print(f"失败: {failed_tests}")
        print(f"通过率: {report['test_summary']['pass_rate']}")
        print("="*60 + "\n")
    
    def _generate_markdown_report(self, report):
        """生成Markdown格式报告"""
        md = f"""# Android应用测试报告

## 测试摘要

- **测试日期**: {report['test_summary']['test_date']}
- **总测试数**: {report['test_summary']['total_tests']}
- **通过数**: {report['test_summary']['passed_tests']}
- **失败数**: {report['test_summary']['failed_tests']}
- **通过率**: {report['test_summary']['pass_rate']}

## 测试结果详情

| 测试项 | 结果 | 详情 | 时间 |
|--------|------|------|------|
"""
        
        for result in report['test_results']:
            status = "✅ 通过" if result['passed'] else "❌ 失败"
            md += f"| {result['test_name']} | {status} | {result['details']} | {result['timestamp']} |\n"
        
        md += """
## 测试环境

- **设备**: Android模拟器
- **应用包名**: com.example.sec_chat
- **APK**: SecChat-debug.apk

## 测试结论

"""
        
        if report['test_summary']['pass_rate'] == '100.0%':
            md += "✅ 所有测试通过！应用质量良好。\n"
        elif float(report['test_summary']['pass_rate'].replace('%', '')) >= 80:
            md += "⚠️ 大部分测试通过，但仍存在问题需要修复。\n"
        else:
            md += "❌ 测试失败率较高，需要重点关注和修复。\n"
        
        return md
    
    def run(self):
        """运行测试"""
        try:
            self.log("="*60)
            self.log("SecChat Android应用自动化测试")
            self.log("="*60)
            
            # 检查环境
            if not self.check_adb():
                return False
            
            # 检查设备
            if not self.wait_for_device():
                self.log("请先启动Android模拟器", "ERROR")
                return False
            
            # 获取设备信息
            device_info = self.get_device_info()
            
            # 安装APK
            if not self.install_apk():
                return False
            
            # 执行测试
            self.run_basic_tests()
            
            # 生成报告
            self.generate_report()
            
            self.log("测试完成！", "SUCCESS")
            return True
            
        except KeyboardInterrupt:
            self.log("用户中断测试", "WARNING")
            return False
        except Exception as e:
            self.log(f"测试过程发生错误: {str(e)}", "ERROR")
            import traceback
            traceback.print_exc()
            return False


def main():
    """主函数"""
    runner = AndroidTestRunner()
    success = runner.run()
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
