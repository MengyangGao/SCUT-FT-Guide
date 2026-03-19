//=============================================================================
// Socket FTP 文件传输系统 (分离目录增强版)
// 特性：服务端/客户端目录分离、实时路径显示、修复输出延迟
//=============================================================================

#include <winsock2.h>
#include <ws2tcpip.h>
#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <windows.h>
#include <direct.h>
#include <io.h>
#include <thread>
#include <sstream>
#include <mutex>
#include <iomanip>
#include <ctime>
#include <chrono>

#pragma comment(lib, "ws2_32.lib")

//=============================================================================
// 协议定义和公共结构
//=============================================================================

#define DEFAULT_PORT 8080
#define BUFFER_SIZE 4096
#define MAX_PATH_LEN 1024

// 文件夹配置
#define SERVER_ROOT_DIR "server_files"
#define CLIENT_ROOT_DIR "client_files"

// 命令类型
enum CommandType
{
    CMD_LIST = 1,     // 列出文件/目录
    CMD_CHDIR = 2,    // 改变目录
    CMD_DOWNLOAD = 3, // 下载文件
    CMD_UPLOAD = 4,   // 上传文件
    CMD_MKDIR = 5,    // 创建目录
    CMD_RMDIR = 6,    // 删除目录
    CMD_DELETE = 7,   // 删除文件
    CMD_PWD = 8,      // 显示当前目录
    CMD_QUIT = 9      // 退出
};

// 响应状态
enum ResponseStatus
{
    STATUS_OK = 200,
    STATUS_ERROR = 400,
    STATUS_NOT_FOUND = 404,
    STATUS_PERMISSION_DENIED = 403
};

// 协议消息结构
struct Message
{
    int command;            // 命令类型
    int status;             // 状态码
    int dataLength;         // 数据长度
    char data[BUFFER_SIZE]; // 数据内容

    Message()
    {
        memset(this, 0, sizeof(Message));
    }
};

//=============================================================================
// 文件系统工具
//=============================================================================

class FileSystemUtils
{
public:
    // 创建目录（如果不存在）
    static bool CreateDirectoryIfNotExists(const std::string &path)
    {
        DWORD attrs = GetFileAttributesA(path.c_str());
        if (attrs == INVALID_FILE_ATTRIBUTES)
        {
            // 目录不存在，创建它
            if (_mkdir(path.c_str()) == 0)
            {
                std::cout << "[INFO] 创建目录: " << path << std::endl;
                return true;
            }
            else
            {
                std::cerr << "[ERROR] 无法创建目录: " << path << std::endl;
                return false;
            }
        }
        else if (attrs & FILE_ATTRIBUTE_DIRECTORY)
        {
            // 目录已存在
            return true;
        }
        else
        {
            // 存在同名文件
            std::cerr << "[ERROR] 存在同名文件，无法创建目录: " << path << std::endl;
            return false;
        }
    }

    // 检查路径是否在允许的根目录内
    static bool IsPathSafe(const std::string &rootDir, const std::string &path)
    {
        // 获取绝对路径
        char resolvedRoot[MAX_PATH];
        char resolvedPath[MAX_PATH];

        if (!_fullpath(resolvedRoot, rootDir.c_str(), MAX_PATH) ||
            !_fullpath(resolvedPath, path.c_str(), MAX_PATH))
        {
            return false;
        }

        std::string root(resolvedRoot);
        std::string target(resolvedPath);

        // 确保目标路径在根目录内
        return target.find(root) == 0;
    }

    // 标准化路径分隔符
    static std::string NormalizePath(const std::string &path)
    {
        std::string normalized = path;
        for (char &c : normalized)
        {
            if (c == '/')
                c = '\\';
        }
        return normalized;
    }

    // 获取相对于根目录的路径
    static std::string GetRelativePath(const std::string &rootDir, const std::string &fullPath)
    {
        char resolvedRoot[MAX_PATH];
        char resolvedPath[MAX_PATH];

        if (!_fullpath(resolvedRoot, rootDir.c_str(), MAX_PATH) ||
            !_fullpath(resolvedPath, fullPath.c_str(), MAX_PATH))
        {
            return ".";
        }

        std::string root(resolvedRoot);
        std::string target(resolvedPath);

        if (target.find(root) == 0)
        {
            std::string relative = target.substr(root.length());
            if (relative.empty() || relative[0] != '\\')
            {
                return ".";
            }
            return relative.substr(1); // 去掉开头的反斜杠
        }
        return ".";
    }
};

//=============================================================================
// 日志系统
//=============================================================================

class Logger
{
private:
    static std::mutex logMutex;
    static bool enableConsoleLog;
    static bool enableFileLog;
    static std::string logFileName;

public:
    enum LogLevel
    {
        INFO = 0,
        WARNING = 1,
        _ERROR = 2,
        SUCCESS = 3
    };

    static void SetConsoleLog(bool enable)
    {
        enableConsoleLog = enable;
    }

    static void SetFileLog(bool enable, const std::string &filename = "ftp_server.log")
    {
        enableFileLog = enable;
        logFileName = filename;
    }

    static void Log(LogLevel level, const std::string &clientIP, const std::string &message)
    {
        std::lock_guard<std::mutex> lock(logMutex);

        // 获取当前时间
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      now.time_since_epoch()) %
                  1000;

        struct tm timeinfo;
        localtime_s(&timeinfo, &time_t);

        // 格式化时间戳
        std::ostringstream timestamp;
        timestamp << std::put_time(&timeinfo, "%Y-%m-%d %H:%M:%S");
        timestamp << "." << std::setfill('0') << std::setw(3) << ms.count();

        // 确定日志级别标识
        std::string levelStr;
        std::string colorCode = "";
        switch (level)
        {
        case INFO:
            levelStr = "[INFO]";
            colorCode = "\033[37m"; // 白色
            break;
        case WARNING:
            levelStr = "[WARN]";
            colorCode = "\033[33m"; // 黄色
            break;
        case _ERROR:
            levelStr = "[ERROR]";
            colorCode = "\033[31m"; // 红色
            break;
        case SUCCESS:
            levelStr = "[SUCCESS]";
            colorCode = "\033[32m"; // 绿色
            break;
        }

        // 构建日志消息
        std::ostringstream logMessage;
        logMessage << timestamp.str() << " " << levelStr
                   << " [" << clientIP << "] " << message;

        // 控制台输出
        if (enableConsoleLog)
        {
            // 在Windows中，ANSI颜色代码需要启用
            HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            DWORD mode;
            GetConsoleMode(hConsole, &mode);
            SetConsoleMode(hConsole, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

            std::cout << colorCode << logMessage.str() << "\033[0m" << std::endl;
            std::cout.flush(); // 立即刷新缓冲区
        }

        // 文件输出
        if (enableFileLog)
        {
            std::ofstream logFile(logFileName, std::ios::app);
            if (logFile.is_open())
            {
                logFile << logMessage.str() << std::endl;
                logFile.close();
            }
        }
    }

    // 便捷方法
    static void LogInfo(const std::string &clientIP, const std::string &message)
    {
        Log(INFO, clientIP, message);
    }

    static void LogWarning(const std::string &clientIP, const std::string &message)
    {
        Log(WARNING, clientIP, message);
    }

    static void LogError(const std::string &clientIP, const std::string &message)
    {
        Log(_ERROR, clientIP, message);
    }

    static void LogSuccess(const std::string &clientIP, const std::string &message)
    {
        Log(SUCCESS, clientIP, message);
    }

    // 系统级日志（无客户端IP）
    static void LogSystem(LogLevel level, const std::string &message)
    {
        Log(level, "SYSTEM", message);
    }
};

// 静态成员初始化
std::mutex Logger::logMutex;
bool Logger::enableConsoleLog = true;
bool Logger::enableFileLog = false;
std::string Logger::logFileName = "ftp_server.log";

//=============================================================================
// 工具函数
//=============================================================================

class SocketUtils
{
public:
    // 发送完整消息
    static bool SendMessage(SOCKET sock, const Message &msg)
    {
        int totalSent = 0;
        int msgSize = sizeof(Message);
        const char *data = reinterpret_cast<const char *>(&msg);

        while (totalSent < msgSize)
        {
            int sent = send(sock, data + totalSent, msgSize - totalSent, 0);
            if (sent == SOCKET_ERROR)
            {
                std::cerr << "发送失败: " << WSAGetLastError() << std::endl;
                std::cerr.flush();
                return false;
            }
            totalSent += sent;
        }
        return true;
    }

    // 接收完整消息
    static bool ReceiveMessage(SOCKET sock, Message &msg)
    {
        int totalReceived = 0;
        int msgSize = sizeof(Message);
        char *data = reinterpret_cast<char *>(&msg);

        while (totalReceived < msgSize)
        {
            int received = recv(sock, data + totalReceived, msgSize - totalReceived, 0);
            if (received == SOCKET_ERROR || received == 0)
            {
                return false;
            }
            totalReceived += received;
        }
        return true;
    }

    // 发送文件
    static bool SendFile(SOCKET sock, const std::string &filepath)
    {
        std::ifstream file(filepath, std::ios::binary);
        if (!file.is_open())
        {
            return false;
        }

        // 获取文件大小
        file.seekg(0, std::ios::end);
        long fileSize = static_cast<long>(file.tellg());
        file.seekg(0, std::ios::beg);

        // 发送文件大小
        Message sizeMsg;
        sizeMsg.command = CMD_UPLOAD;
        sizeMsg.dataLength = fileSize;
        if (!SendMessage(sock, sizeMsg))
        {
            file.close();
            return false;
        }

        // 发送文件内容
        char buffer[BUFFER_SIZE];
        while (!file.eof())
        {
            file.read(buffer, BUFFER_SIZE);
            int bytesRead = static_cast<int>(file.gcount());
            if (bytesRead > 0)
            {
                int totalSent = 0;
                while (totalSent < bytesRead)
                {
                    int sent = send(sock, buffer + totalSent, bytesRead - totalSent, 0);
                    if (sent == SOCKET_ERROR)
                    {
                        file.close();
                        return false;
                    }
                    totalSent += sent;
                }
            }
        }

        file.close();
        return true;
    }

    // 接收文件
    static bool ReceiveFile(SOCKET sock, const std::string &filepath, long fileSize)
    {
        std::ofstream file(filepath, std::ios::binary);
        if (!file.is_open())
        {
            return false;
        }

        char buffer[BUFFER_SIZE];
        long totalReceived = 0;

        while (totalReceived < fileSize)
        {
            int toReceive = static_cast<int>(min(static_cast<long>(BUFFER_SIZE), fileSize - totalReceived));
            int received = recv(sock, buffer, toReceive, 0);
            if (received == SOCKET_ERROR || received == 0)
            {
                file.close();
                return false;
            }

            file.write(buffer, received);
            totalReceived += received;
        }

        file.close();
        return true;
    }
};

//=============================================================================
// 服务器端实现
//=============================================================================

class FTPServer
{
private:
    SOCKET serverSocket;
    std::string rootDirectory;
    bool isRunning;

public:
    FTPServer() : isRunning(false)
    {
        serverSocket = INVALID_SOCKET;
        rootDirectory = SERVER_ROOT_DIR;

        // 创建服务器根目录
        if (!FileSystemUtils::CreateDirectoryIfNotExists(rootDirectory))
        {
            throw std::runtime_error("无法创建服务器根目录");
        }

        // 启用控制台和文件日志
        Logger::SetConsoleLog(true);
        Logger::SetFileLog(true, "ftp_server.log");
    }

    ~FTPServer()
    {
        Stop();
    }

    bool Initialize()
    {
        // 初始化Winsock
        WSADATA wsaData;
        int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
        if (result != 0)
        {
            std::cerr << "WSAStartup失败: " << result << std::endl;
            std::cerr.flush();
            return false;
        }

        // 创建套接字
        serverSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (serverSocket == INVALID_SOCKET)
        {
            std::cerr << "创建套接字失败: " << WSAGetLastError() << std::endl;
            std::cerr.flush();
            WSACleanup();
            return false;
        }

        // 设置地址重用
        int opt = 1;
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt));

        return true;
    }

    bool Start(int port = DEFAULT_PORT)
    {
        if (!Initialize())
        {
            return false;
        }

        // 绑定地址
        sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(port);

        if (bind(serverSocket, (sockaddr *)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR)
        {
            std::cerr << "绑定失败: " << WSAGetLastError() << std::endl;
            std::cerr.flush();
            closesocket(serverSocket);
            WSACleanup();
            return false;
        }

        // 开始监听
        if (listen(serverSocket, SOMAXCONN) == SOCKET_ERROR)
        {
            std::cerr << "监听失败: " << WSAGetLastError() << std::endl;
            std::cerr.flush();
            closesocket(serverSocket);
            WSACleanup();
            return false;
        }

        isRunning = true;
        Logger::LogSystem(Logger::SUCCESS, "FTP服务器启动成功，监听端口: " + std::to_string(port));
        Logger::LogSystem(Logger::INFO, "服务器根目录: " + rootDirectory);
        std::cout << "\n=== 服务器日志 ===" << std::endl;
        std::cout.flush();

        // 接受客户端连接
        while (isRunning)
        {
            sockaddr_in clientAddr;
            int clientAddrLen = sizeof(clientAddr);
            SOCKET clientSocket = accept(serverSocket, (sockaddr *)&clientAddr, &clientAddrLen);

            if (clientSocket == INVALID_SOCKET)
            {
                if (isRunning)
                {
                    std::cerr << "接受连接失败: " << WSAGetLastError() << std::endl;
                    std::cerr.flush();
                }
                continue;
            }

            char clientIP[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &clientAddr.sin_addr, clientIP, INET_ADDRSTRLEN);
            int clientPort = ntohs(clientAddr.sin_port);

            std::string clientAddress = std::string(clientIP) + ":" + std::to_string(clientPort);
            Logger::LogSuccess(clientAddress, "客户端连接成功");

            // 为每个客户端创建处理线程
            std::thread clientThread(&FTPServer::HandleClient, this, clientSocket, clientAddress);
            clientThread.detach();
        }

        return true;
    }

    void Stop()
    {
        isRunning = false;
        Logger::LogSystem(Logger::INFO, "正在关闭FTP服务器...");
        if (serverSocket != INVALID_SOCKET)
        {
            closesocket(serverSocket);
            serverSocket = INVALID_SOCKET;
        }
        WSACleanup();
        Logger::LogSystem(Logger::SUCCESS, "FTP服务器已关闭");
    }

private:
    std::string GetCommandName(int command)
    {
        switch (command)
        {
        case CMD_LIST:
            return "LIST";
        case CMD_CHDIR:
            return "CHDIR";
        case CMD_DOWNLOAD:
            return "DOWNLOAD";
        case CMD_UPLOAD:
            return "UPLOAD";
        case CMD_MKDIR:
            return "MKDIR";
        case CMD_RMDIR:
            return "RMDIR";
        case CMD_DELETE:
            return "DELETE";
        case CMD_PWD:
            return "PWD";
        case CMD_QUIT:
            return "QUIT";
        default:
            return "UNKNOWN";
        }
    }

    void HandleClient(SOCKET clientSocket, const std::string &clientAddress)
    {
        std::string currentDir = rootDirectory;
        Message request, response;

        Logger::LogInfo(clientAddress, "开始处理客户端会话，当前目录: " + currentDir);

        while (true)
        {
            // 接收客户端请求
            if (!SocketUtils::ReceiveMessage(clientSocket, request))
            {
                Logger::LogWarning(clientAddress, "接收客户端请求失败，连接可能已断开");
                break;
            }

            // 记录收到的命令
            std::string commandName = GetCommandName(request.command);
            std::string logMsg = "收到命令: " + commandName;
            if (strlen(request.data) > 0)
            {
                logMsg += " 参数: " + std::string(request.data);
            }
            Logger::LogInfo(clientAddress, logMsg);

            // 处理请求
            response = Message();
            response.command = request.command;

            switch (request.command)
            {
            case CMD_LIST:
                HandleListCommand(currentDir, response, clientAddress);
                break;
            case CMD_CHDIR:
                HandleChdirCommand(currentDir, request.data, response, clientAddress);
                break;
            case CMD_DOWNLOAD:
                HandleDownloadCommand(currentDir, request.data, response, clientSocket, clientAddress);
                break;
            case CMD_UPLOAD:
                HandleUploadCommand(currentDir, request.data, response, clientSocket, clientAddress);
                break;
            case CMD_MKDIR:
                HandleMkdirCommand(currentDir, request.data, response, clientAddress);
                break;
            case CMD_RMDIR:
                HandleRmdirCommand(currentDir, request.data, response, clientAddress);
                break;
            case CMD_DELETE:
                HandleDeleteCommand(currentDir, request.data, response, clientAddress);
                break;
            case CMD_PWD:
                HandlePwdCommand(currentDir, response, clientAddress);
                break;
            case CMD_QUIT:
                response.status = STATUS_OK;
                strcpy_s(response.data, "再见!");
                SocketUtils::SendMessage(clientSocket, response);
                Logger::LogInfo(clientAddress, "客户端请求断开连接");
                goto cleanup;
            default:
                response.status = STATUS_ERROR;
                strcpy_s(response.data, "未知命令");
                Logger::LogWarning(clientAddress, "收到未知命令: " + std::to_string(request.command));
                break;
            }

            // 发送响应
            if (!SocketUtils::SendMessage(clientSocket, response))
            {
                Logger::LogError(clientAddress, "发送响应失败");
                break;
            }

            // 记录响应状态
            if (response.status == STATUS_OK)
            {
                Logger::LogSuccess(clientAddress, commandName + " 命令执行成功");
            }
            else
            {
                Logger::LogError(clientAddress, commandName + " 命令执行失败: " + std::string(response.data));
            }
        }

    cleanup:
        closesocket(clientSocket);
        Logger::LogInfo(clientAddress, "客户端连接已关闭");
    }

    void HandleListCommand(const std::string &currentDir, Message &response, const std::string &clientAddress)
    {
        WIN32_FIND_DATAA findData;
        HANDLE hFind;
        std::string searchPath = currentDir + "\\*";
        std::string result;
        int fileCount = 0, dirCount = 0;

        hFind = FindFirstFileA(searchPath.c_str(), &findData);
        if (hFind == INVALID_HANDLE_VALUE)
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "无法读取目录");
            Logger::LogError(clientAddress, "LIST命令失败: 无法读取目录 " + currentDir);
            return;
        }

        do
        {
            if (strcmp(findData.cFileName, ".") != 0 && strcmp(findData.cFileName, "..") != 0)
            {
                if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                {
                    result += "[DIR] ";
                    dirCount++;
                }
                else
                {
                    result += "[FILE] ";
                    fileCount++;
                }
                result += findData.cFileName;
                result += "\n";
            }
        } while (FindNextFileA(hFind, &findData));

        FindClose(hFind);

        response.status = STATUS_OK;
        strncpy_s(response.data, result.c_str(), sizeof(response.data) - 1);

        std::string relativePath = FileSystemUtils::GetRelativePath(rootDirectory, currentDir);
        std::ostringstream logMsg;
        logMsg << "LIST命令成功: 目录 /" << relativePath << " (文件: " << fileCount << ", 目录: " << dirCount << ")";
        Logger::LogInfo(clientAddress, logMsg.str());
    }

    void HandleChdirCommand(std::string &currentDir, const char *path, Message &response, const std::string &clientAddress)
    {
        std::string oldDir = currentDir;
        std::string newPath;

        if (strcmp(path, "..") == 0)
        {
            // 向上一级目录
            if (currentDir != rootDirectory)
            {
                size_t lastSlash = currentDir.find_last_of('\\');
                if (lastSlash != std::string::npos && lastSlash > rootDirectory.length())
                {
                    newPath = currentDir.substr(0, lastSlash);
                }
                else
                {
                    newPath = rootDirectory;
                }
            }
            else
            {
                newPath = rootDirectory; // 已在根目录
            }
        }
        else if (path[0] == '\\' || path[1] == ':')
        {
            // 绝对路径 - 不允许
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "不允许使用绝对路径");
            Logger::LogWarning(clientAddress, "CHDIR命令失败: 尝试使用绝对路径 " + std::string(path));
            return;
        }
        else
        {
            // 相对路径
            newPath = currentDir + "\\" + path;
        }

        // 安全检查：确保新路径在根目录内
        if (!FileSystemUtils::IsPathSafe(rootDirectory, newPath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝：超出允许范围");
            Logger::LogWarning(clientAddress, "CHDIR命令失败: 路径超出范围 " + std::string(path));
            return;
        }

        // 检查目录是否存在
        DWORD attrs = GetFileAttributesA(newPath.c_str());
        if (attrs == INVALID_FILE_ATTRIBUTES || !(attrs & FILE_ATTRIBUTE_DIRECTORY))
        {
            response.status = STATUS_NOT_FOUND;
            strcpy_s(response.data, "目录不存在");
            Logger::LogWarning(clientAddress, "CHDIR命令失败: 目录不存在 " + std::string(path));
            return;
        }

        currentDir = newPath;
        response.status = STATUS_OK;
        strcpy_s(response.data, "目录已更改");

        std::string oldRelative = FileSystemUtils::GetRelativePath(rootDirectory, oldDir);
        std::string newRelative = FileSystemUtils::GetRelativePath(rootDirectory, currentDir);
        Logger::LogInfo(clientAddress, "CHDIR命令成功: /" + oldRelative + " -> /" + newRelative);
    }

    void HandleDownloadCommand(const std::string &currentDir, const char *filename,
                               Message &response, SOCKET clientSocket, const std::string &clientAddress)
    {
        std::string filepath = currentDir + "\\" + filename;

        // 安全检查
        if (!FileSystemUtils::IsPathSafe(rootDirectory, filepath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝");
            Logger::LogError(clientAddress, "DOWNLOAD命令失败: 路径不安全 " + std::string(filename));
            return;
        }

        // 检查文件是否存在
        if (_access(filepath.c_str(), 0) != 0)
        {
            response.status = STATUS_NOT_FOUND;
            strcpy_s(response.data, "文件不存在");
            Logger::LogWarning(clientAddress, "DOWNLOAD命令失败: 文件不存在 " + std::string(filename));
            return;
        }

        // 获取文件大小
        struct _stat fileStat;
        if (_stat(filepath.c_str(), &fileStat) != 0)
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "无法获取文件信息");
            Logger::LogError(clientAddress, "DOWNLOAD命令失败: 无法获取文件信息 " + std::string(filename));
            return;
        }

        response.status = STATUS_OK;
        response.dataLength = static_cast<int>(fileStat.st_size);
        strcpy_s(response.data, "开始文件传输");

        Logger::LogInfo(clientAddress, "开始下载文件: " + std::string(filename) +
                                           " (大小: " + std::to_string(fileStat.st_size) + " 字节)");

        // 发送响应头
        if (!SocketUtils::SendMessage(clientSocket, response))
        {
            Logger::LogError(clientAddress, "DOWNLOAD命令失败: 发送响应头失败");
            return;
        }

        // 发送文件内容
        std::ifstream file(filepath, std::ios::binary);
        if (!file.is_open())
        {
            Logger::LogError(clientAddress, "DOWNLOAD命令失败: 无法打开文件 " + std::string(filename));
            return;
        }

        char buffer[BUFFER_SIZE];
        long totalSent = 0;
        while (!file.eof())
        {
            file.read(buffer, BUFFER_SIZE);
            int bytesRead = static_cast<int>(file.gcount());
            if (bytesRead > 0)
            {
                if (send(clientSocket, buffer, bytesRead, 0) == SOCKET_ERROR)
                {
                    Logger::LogError(clientAddress, "DOWNLOAD命令失败: 发送文件数据失败");
                    file.close();
                    return;
                }
                totalSent += bytesRead;
            }
        }
        file.close();

        Logger::LogSuccess(clientAddress, "DOWNLOAD命令成功: " + std::string(filename) +
                                              " (传输: " + std::to_string(totalSent) + " 字节)");
    }

    void HandleUploadCommand(const std::string &currentDir, const char *filename,
                             Message &response, SOCKET clientSocket, const std::string &clientAddress)
    {
        std::string filepath = currentDir + "\\" + filename;

        // 安全检查
        if (!FileSystemUtils::IsPathSafe(rootDirectory, filepath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝");
            Logger::LogError(clientAddress, "UPLOAD命令失败: 路径不安全 " + std::string(filename));
            return;
        }

        Logger::LogInfo(clientAddress, "开始接收上传文件: " + std::string(filename));

        // 接收文件大小
        Message sizeMsg;
        if (!SocketUtils::ReceiveMessage(clientSocket, sizeMsg))
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "接收文件大小失败");
            Logger::LogError(clientAddress, "UPLOAD命令失败: 接收文件大小失败");
            return;
        }

        long fileSize = sizeMsg.dataLength;
        Logger::LogInfo(clientAddress, "准备接收文件: " + std::string(filename) +
                                           " (大小: " + std::to_string(fileSize) + " 字节)");

        // 接收文件内容
        if (!SocketUtils::ReceiveFile(clientSocket, filepath, fileSize))
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "文件上传失败");
            Logger::LogError(clientAddress, "UPLOAD命令失败: 接收文件数据失败 " + std::string(filename));
            return;
        }

        response.status = STATUS_OK;
        strcpy_s(response.data, "文件上传成功");
        Logger::LogSuccess(clientAddress, "UPLOAD命令成功: " + std::string(filename) +
                                              " (大小: " + std::to_string(fileSize) + " 字节)");
    }

    void HandleMkdirCommand(const std::string &currentDir, const char *dirname, Message &response, const std::string &clientAddress)
    {
        std::string dirpath = currentDir + "\\" + dirname;

        // 安全检查
        if (!FileSystemUtils::IsPathSafe(rootDirectory, dirpath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝");
            Logger::LogError(clientAddress, "MKDIR命令失败: 路径不安全 " + std::string(dirname));
            return;
        }

        if (_mkdir(dirpath.c_str()) == 0)
        {
            response.status = STATUS_OK;
            strcpy_s(response.data, "目录创建成功");
            Logger::LogSuccess(clientAddress, "MKDIR命令成功: 创建目录 " + std::string(dirname));
        }
        else
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "目录创建失败");
            Logger::LogError(clientAddress, "MKDIR命令失败: 无法创建目录 " + std::string(dirname));
        }
    }

    void HandleRmdirCommand(const std::string &currentDir, const char *dirname, Message &response, const std::string &clientAddress)
    {
        std::string dirpath = currentDir + "\\" + dirname;

        // 安全检查
        if (!FileSystemUtils::IsPathSafe(rootDirectory, dirpath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝");
            Logger::LogError(clientAddress, "RMDIR命令失败: 路径不安全 " + std::string(dirname));
            return;
        }

        if (_rmdir(dirpath.c_str()) == 0)
        {
            response.status = STATUS_OK;
            strcpy_s(response.data, "目录删除成功");
            Logger::LogSuccess(clientAddress, "RMDIR命令成功: 删除目录 " + std::string(dirname));
        }
        else
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "目录删除失败");
            Logger::LogError(clientAddress, "RMDIR命令失败: 无法删除目录 " + std::string(dirname));
        }
    }

    void HandleDeleteCommand(const std::string &currentDir, const char *filename, Message &response, const std::string &clientAddress)
    {
        std::string filepath = currentDir + "\\" + filename;

        // 安全检查
        if (!FileSystemUtils::IsPathSafe(rootDirectory, filepath))
        {
            response.status = STATUS_PERMISSION_DENIED;
            strcpy_s(response.data, "访问被拒绝");
            Logger::LogError(clientAddress, "DELETE命令失败: 路径不安全 " + std::string(filename));
            return;
        }

        if (remove(filepath.c_str()) == 0)
        {
            response.status = STATUS_OK;
            strcpy_s(response.data, "文件删除成功");
            Logger::LogSuccess(clientAddress, "DELETE命令成功: 删除文件 " + std::string(filename));
        }
        else
        {
            response.status = STATUS_ERROR;
            strcpy_s(response.data, "文件删除失败");
            Logger::LogError(clientAddress, "DELETE命令失败: 无法删除文件 " + std::string(filename));
        }
    }

    void HandlePwdCommand(const std::string &currentDir, Message &response, const std::string &clientAddress)
    {
        std::string relativePath = FileSystemUtils::GetRelativePath(rootDirectory, currentDir);
        response.status = STATUS_OK;
        strcpy_s(response.data, ("/" + relativePath).c_str());
        Logger::LogInfo(clientAddress, "PWD命令: 当前目录 /" + relativePath);
    }
};

//=============================================================================
// 客户端实现
//=============================================================================

class FTPClient
{
private:
    SOCKET clientSocket;
    bool isConnected;
    std::string currentPath;
    std::string rootDirectory;

public:
    FTPClient() : isConnected(false), currentPath("/")
    {
        clientSocket = INVALID_SOCKET;
        rootDirectory = CLIENT_ROOT_DIR;

        // 创建客户端根目录
        if (!FileSystemUtils::CreateDirectoryIfNotExists(rootDirectory))
        {
            throw std::runtime_error("无法创建客户端根目录");
        }
    }

    ~FTPClient()
    {
        Disconnect();
    }

    bool Initialize()
    {
        // 初始化Winsock
        WSADATA wsaData;
        int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
        if (result != 0)
        {
            std::cerr << "WSAStartup失败: " << result << std::endl;
            std::cerr.flush();
            return false;
        }
        return true;
    }

    bool Connect(const std::string &serverIP, int port = DEFAULT_PORT)
    {
        if (!Initialize())
        {
            return false;
        }

        // 创建套接字
        clientSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (clientSocket == INVALID_SOCKET)
        {
            std::cerr << "创建套接字失败: " << WSAGetLastError() << std::endl;
            std::cerr.flush();
            WSACleanup();
            return false;
        }

        // 连接服务器
        sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        inet_pton(AF_INET, serverIP.c_str(), &serverAddr.sin_addr);
        serverAddr.sin_port = htons(port);

        if (connect(clientSocket, (sockaddr *)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR)
        {
            std::cerr << "连接服务器失败: " << WSAGetLastError() << std::endl;
            std::cerr.flush();
            closesocket(clientSocket);
            WSACleanup();
            return false;
        }

        isConnected = true;
        std::cout << "连接服务器成功: " << serverIP << ":" << port << std::endl;
        std::cout << "客户端工作目录: " << rootDirectory << std::endl;
        std::cout.flush();

        // 获取初始服务器路径
        UpdateServerPath();
        return true;
    }

    void Disconnect()
    {
        if (isConnected)
        {
            SendQuitCommand();
            isConnected = false;
        }
        if (clientSocket != INVALID_SOCKET)
        {
            closesocket(clientSocket);
            clientSocket = INVALID_SOCKET;
        }
        WSACleanup();
    }

    void Run()
    {
        if (!isConnected)
        {
            std::cout << "未连接到服务器" << std::endl;
            std::cout.flush();
            return;
        }

        std::string command;
        std::cout << "\n=== 欢迎使用FTP客户端! ===" << std::endl;
        std::cout << "支持的命令: list, cd <目录>, get <文件名>, put <文件名>, mkdir <目录名>, rmdir <目录名>, del <文件名>, pwd, quit" << std::endl;
        std::cout << "提示：get下载文件到 " << rootDirectory << " 目录，put上传 " << rootDirectory << " 目录中的文件" << std::endl;
        std::cout.flush();

        ShowPrompt();

        while (true)
        {
            std::getline(std::cin, command);

            if (command.empty())
            {
                ShowPrompt();
                continue;
            }

            std::istringstream iss(command);
            std::string cmd, arg;
            iss >> cmd >> arg;

            if (cmd == "list" || cmd == "ls")
            {
                SendListCommand();
            }
            else if (cmd == "cd")
            {
                if (!arg.empty())
                {
                    SendChdirCommand(arg);
                }
                else
                {
                    std::cout << "用法: cd <目录名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "get")
            {
                if (!arg.empty())
                {
                    SendDownloadCommand(arg);
                }
                else
                {
                    std::cout << "用法: get <文件名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "put")
            {
                if (!arg.empty())
                {
                    SendUploadCommand(arg);
                }
                else
                {
                    std::cout << "用法: put <文件名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "mkdir")
            {
                if (!arg.empty())
                {
                    SendMkdirCommand(arg);
                }
                else
                {
                    std::cout << "用法: mkdir <目录名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "rmdir")
            {
                if (!arg.empty())
                {
                    SendRmdirCommand(arg);
                }
                else
                {
                    std::cout << "用法: rmdir <目录名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "del" || cmd == "rm")
            {
                if (!arg.empty())
                {
                    SendDeleteCommand(arg);
                }
                else
                {
                    std::cout << "用法: del <文件名>" << std::endl;
                    std::cout.flush();
                }
            }
            else if (cmd == "pwd")
            {
                SendPwdCommand();
            }
            else if (cmd == "quit" || cmd == "exit")
            {
                break;
            }
            else
            {
                std::cout << "未知命令: " << cmd << std::endl;
                std::cout.flush();
            }

            ShowPrompt();
        }
    }

private:
    void ShowPrompt()
    {
        std::cout << "\nftp [" << currentPath << "]> ";
        std::cout.flush();
    }

    void UpdateServerPath()
    {
        Message request;
        request.command = CMD_PWD;

        if (SocketUtils::SendMessage(clientSocket, request))
        {
            Message response;
            if (SocketUtils::ReceiveMessage(clientSocket, response))
            {
                if (response.status == STATUS_OK)
                {
                    currentPath = response.data;
                }
            }
        }
    }

    void SendListCommand()
    {
        Message request;
        request.command = CMD_LIST;

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        if (response.status == STATUS_OK)
        {
            std::cout << "服务器目录内容 [" << currentPath << "]:\n"
                      << response.data << std::endl;
        }
        else
        {
            std::cout << "错误: " << response.data << std::endl;
        }
        std::cout.flush();
    }

    void SendChdirCommand(const std::string &dirname)
    {
        Message request;
        request.command = CMD_CHDIR;
        strcpy_s(request.data, dirname.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        std::cout << response.data << std::endl;
        std::cout.flush();

        if (response.status == STATUS_OK)
        {
            UpdateServerPath();
        }
    }

    void SendDownloadCommand(const std::string &filename)
    {
        Message request;
        request.command = CMD_DOWNLOAD;
        strcpy_s(request.data, filename.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        if (response.status == STATUS_OK)
        {
            std::string localPath = rootDirectory + "\\" + filename;
            std::cout << "开始下载文件: " << filename << " (大小: " << response.dataLength << " 字节)" << std::endl;
            std::cout << "保存到: " << localPath << std::endl;
            std::cout.flush();

            if (SocketUtils::ReceiveFile(clientSocket, localPath, response.dataLength))
            {
                std::cout << "文件下载成功" << std::endl;
            }
            else
            {
                std::cout << "文件下载失败" << std::endl;
            }
        }
        else
        {
            std::cout << "错误: " << response.data << std::endl;
        }
        std::cout.flush();
    }

    void SendUploadCommand(const std::string &filename)
    {
        std::string localPath = rootDirectory + "\\" + filename;

        // 检查本地文件是否存在
        if (_access(localPath.c_str(), 0) != 0)
        {
            std::cout << "本地文件不存在: " << localPath << std::endl;
            std::cout.flush();
            return;
        }

        Message request;
        request.command = CMD_UPLOAD;
        strcpy_s(request.data, filename.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        std::cout << "开始上传文件: " << localPath << std::endl;
        std::cout.flush();

        // 发送文件
        if (SocketUtils::SendFile(clientSocket, localPath))
        {
            Message response;
            if (SocketUtils::ReceiveMessage(clientSocket, response))
            {
                std::cout << response.data << std::endl;
                std::cout.flush();
            }
        }
        else
        {
            std::cout << "文件上传失败" << std::endl;
            std::cout.flush();
        }
    }

    void SendMkdirCommand(const std::string &dirname)
    {
        Message request;
        request.command = CMD_MKDIR;
        strcpy_s(request.data, dirname.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        std::cout << response.data << std::endl;
        std::cout.flush();
    }

    void SendRmdirCommand(const std::string &dirname)
    {
        Message request;
        request.command = CMD_RMDIR;
        strcpy_s(request.data, dirname.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        std::cout << response.data << std::endl;
        std::cout.flush();
    }

    void SendDeleteCommand(const std::string &filename)
    {
        Message request;
        request.command = CMD_DELETE;
        strcpy_s(request.data, filename.c_str());

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        std::cout << response.data << std::endl;
        std::cout.flush();
    }

    void SendPwdCommand()
    {
        Message request;
        request.command = CMD_PWD;

        if (!SocketUtils::SendMessage(clientSocket, request))
        {
            std::cout << "发送命令失败" << std::endl;
            std::cout.flush();
            return;
        }

        Message response;
        if (!SocketUtils::ReceiveMessage(clientSocket, response))
        {
            std::cout << "接收响应失败" << std::endl;
            std::cout.flush();
            return;
        }

        if (response.status == STATUS_OK)
        {
            currentPath = response.data;
            std::cout << "服务器当前目录: " << currentPath << std::endl;
        }
        else
        {
            std::cout << "错误: " << response.data << std::endl;
        }
        std::cout.flush();
    }

    void SendQuitCommand()
    {
        Message request;
        request.command = CMD_QUIT;
        SocketUtils::SendMessage(clientSocket, request);

        Message response;
        SocketUtils::ReceiveMessage(clientSocket, response);
    }
};

//=============================================================================
// 主函数和测试代码
//=============================================================================

void RunServer()
{
    std::cout << "=== Socket FTP 服务器 (分离目录版) ===" << std::endl;
    std::cout << "启动FTP服务器..." << std::endl;
    std::cout.flush();

    try
    {
        // 询问用户是否启用文件日志
        std::cout << "是否启用文件日志? (y/n, 默认: y): ";
        std::cout.flush();
        std::string enableFileLog;
        std::getline(std::cin, enableFileLog);
        bool fileLogEnabled = (enableFileLog.empty() || enableFileLog[0] == 'y' || enableFileLog[0] == 'Y');

        // 询问监听端口
        std::cout << "请输入监听端口 (默认: 8080): ";
        std::cout.flush();
        std::string portStr;
        std::getline(std::cin, portStr);
        int port = portStr.empty() ? DEFAULT_PORT : std::stoi(portStr);

        FTPServer server;

        // 配置日志
        Logger::SetConsoleLog(true);
        Logger::SetFileLog(fileLogEnabled, "ftp_server_" + std::to_string(port) + ".log");

        if (fileLogEnabled)
        {
            std::cout << "文件日志已启用: ftp_server_" << port << ".log" << std::endl;
            std::cout.flush();
        }

        // 启动服务器
        Logger::LogSystem(Logger::INFO, "正在初始化FTP服务器...");
        server.Start(port);
    }
    catch (const std::exception &e)
    {
        std::cerr << "服务器启动失败: " << e.what() << std::endl;
        std::cerr.flush();
    }
}

void RunClient()
{
    std::cout << "=== Socket FTP 客户端 (分离目录版) ===" << std::endl;
    std::cout << "启动FTP客户端..." << std::endl;
    std::cout.flush();

    try
    {
        FTPClient client;

        std::string serverIP;
        std::cout << "请输入服务器IP地址 (默认: 127.0.0.1): ";
        std::cout.flush();
        std::getline(std::cin, serverIP);
        if (serverIP.empty())
        {
            serverIP = "127.0.0.1";
        }

        if (client.Connect(serverIP, DEFAULT_PORT))
        {
            client.Run();
        }

        std::cout << "客户端退出" << std::endl;
        std::cout.flush();
    }
    catch (const std::exception &e)
    {
        std::cerr << "客户端启动失败: " << e.what() << std::endl;
        std::cerr.flush();
    }
}

int main()
{
    std::cout << "=== Socket FTP 文件传输系统 (分离目录增强版) ===" << std::endl;
    std::cout << "特性: 目录分离、实时路径显示、安全权限控制" << std::endl;
    std::cout << "1. 启动服务器 (目录: " << SERVER_ROOT_DIR << ")" << std::endl;
    std::cout << "2. 启动客户端 (目录: " << CLIENT_ROOT_DIR << ")" << std::endl;
    std::cout << "请选择 (1 或 2): ";
    std::cout.flush();

    int choice;
    std::cin >> choice;
    std::cin.ignore(); // 清除输入缓冲区

    switch (choice)
    {
    case 1:
        RunServer();
        break;
    case 2:
        RunClient();
        break;
    default:
        std::cout << "无效选择" << std::endl;
        std::cout.flush();
        break;
    }

    return 0;
}

//=============================================================================
// 编译说明：
// 1. 使用Visual Studio: cl /EHsc main.cpp ws2_32.lib
// 2. 使用MinGW: g++ -o ftp_system.exe main.cpp -lws2_32 -std=c++11
//
// 新增功能详解：
// 1. 目录分离：
//    - 服务器使用 server_files 目录
//    - 客户端使用 client_files 目录
//    - 自动创建目录，避免权限问题
//
// 2. 安全控制：
//    - 路径安全检查，防止目录遍历攻击
//    - 禁止绝对路径访问
//    - 限制操作范围在指定目录内
//
// 3. 实时路径显示：
//    - 客户端提示符显示当前服务器路径
//    - 目录操作后自动更新路径显示
//    - 相对路径显示，便于理解
//
// 4. 修复输出延迟：
//    - 所有输出后添加 flush()
//    - 立即刷新缓冲区，避免延迟显示
//    - 改善用户交互体验
//
// 使用说明：
// - 服务器文件存储在 server_files 目录
// - 客户端文件存储在 client_files 目录
// - get 命令下载到客户端目录
// - put 命令从客户端目录上传
//=============================================================================