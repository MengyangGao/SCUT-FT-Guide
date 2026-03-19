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

constexpr int DEFAULT_LISTEN_PORT = 9090;
constexpr int PACKET_PAYLOAD_SIZE = 4096;
constexpr int MAX_PATH_LENGTH = 1024;

const char *const HOST_ROOT_PATH = "host_storage";
const char *const CLIENT_ROOT_PATH = "client_storage";

enum class OperationCode
{
    LIST_FILES = 1,
    CHANGE_DIR = 2,
    INITIATE_DOWNLOAD = 3,
    INITIATE_UPLOAD = 4,
    CREATE_DIR = 5,
    REMOVE_DIR = 6,
    DELETE_FILE = 7,
    GET_CURRENT_PATH = 8,
    TERMINATE = 9
};

enum class StatusCode
{
    SUCCESS = 200,
    REQUEST_ERROR = 400,
    NOT_FOUND_ERROR = 404,
    FORBIDDEN_ERROR = 403
};

struct TransferPacket
{
    int opCode;
    int resultCode;
    int payloadSize;
    char payload[PACKET_PAYLOAD_SIZE];

    TransferPacket()
    {
        memset(this, 0, sizeof(TransferPacket));
    }
};

//=============================================================================

class PathManager
{
public:
    static bool EnsureDirectoryExists(const std::string &path)
    {
        DWORD attributes = GetFileAttributesA(path.c_str());
        if (attributes == INVALID_FILE_ATTRIBUTES)
        {
            if (_mkdir(path.c_str()) == 0)
            {
                std::cout << "[SYSTEM] Created directory: " << path << std::endl;
                return true;
            }
            else
            {
                std::cerr << "[FATAL] Could not create directory: " << path << std::endl;
                return false;
            }
        }
        if (attributes & FILE_ATTRIBUTE_DIRECTORY)
        {
            return true;
        }
        std::cerr << "[FATAL] A file with the same name exists: " << path << std::endl;
        return false;
    }

    static bool IsPathWithinBounds(const std::string &root, const std::string &targetPath)
    {
        char absoluteRoot[MAX_PATH_LENGTH];
        char absoluteTarget[MAX_PATH_LENGTH];

        if (!_fullpath(absoluteRoot, root.c_str(), MAX_PATH_LENGTH) ||
            !_fullpath(absoluteTarget, targetPath.c_str(), MAX_PATH_LENGTH))
        {
            return false;
        }

        std::string rootStr(absoluteRoot);
        std::string targetStr(absoluteTarget);

        return targetStr.rfind(rootStr, 0) == 0;
    }

    static std::string NormalizePath(const std::string &path)
    {
        std::string result = path;
        for (char &c : result)
        {
            if (c == '/')
                c = '\\';
        }
        return result;
    }

    static std::string GetRelativeLocation(const std::string &root, const std::string &fullPath)
    {
        char absoluteRoot[MAX_PATH_LENGTH];
        char absolutePath[MAX_PATH_LENGTH];

        if (!_fullpath(absoluteRoot, root.c_str(), MAX_PATH_LENGTH) ||
            !_fullpath(absolutePath, fullPath.c_str(), MAX_PATH_LENGTH))
        {
            return ".";
        }

        std::string rootStr(absoluteRoot);
        std::string pathStr(absolutePath);

        if (pathStr.rfind(rootStr, 0) == 0)
        {
            std::string relative = pathStr.substr(rootStr.length());
            if (relative.empty() || relative[0] != '\\')
            {
                return ".";
            }
            return relative.substr(1);
        }
        return ".";
    }
};

//=============================================================================

class EventLogger
{
private:
    static std::mutex s_logMutex;
    static bool s_isConsoleLoggingEnabled;
    static bool s_isFileLoggingEnabled;
    static std::string s_logFilename;

public:
    enum class Level
    {
        Info,
        Warning,
        Error,
        Success
    };

    static void EnableConsoleLogging(bool enabled)
    {
        s_isConsoleLoggingEnabled = enabled;
    }

    static void EnableFileLogging(bool enabled, const std::string &filename = "file_hub_host.log")
    {
        s_isFileLoggingEnabled = enabled;
        s_logFilename = filename;
    }

    static void Record(Level level, const std::string &sourceIP, const std::string &message)
    {
        std::lock_guard<std::mutex> guard(s_logMutex);

        auto now = std::chrono::system_clock::now();
        auto time = std::chrono::system_clock::to_time_t(now);
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

        tm timeInfo;
        localtime_s(&timeInfo, &time);

        std::ostringstream timestampStream;
        timestampStream << std::put_time(&timeInfo, "%Y-%m-%d %H:%M:%S");
        timestampStream << "." << std::setfill('0') << std::setw(3) << ms.count();

        std::string levelTag;
        std::string colorCode;
        switch (level)
        {
        case Level::Info:
            levelTag = "[INFO]";
            colorCode = "\033[37m";
            break;
        case Level::Warning:
            levelTag = "[WARN]";
            colorCode = "\033[33m";
            break;
        case Level::Error:
            levelTag = "[ERROR]";
            colorCode = "\033[31m";
            break;
        case Level::Success:
            levelTag = "[SUCCESS]";
            colorCode = "\033[32m";
            break;
        }

        std::ostringstream logEntry;
        logEntry << timestampStream.str() << " " << levelTag << " [" << sourceIP << "] " << message;

        if (s_isConsoleLoggingEnabled)
        {
            HANDLE hConsole = GetStdHandle(STD_OUTPUT_HANDLE);
            DWORD consoleMode;
            GetConsoleMode(hConsole, &consoleMode);
            SetConsoleMode(hConsole, consoleMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING);

            std::cout << colorCode << logEntry.str() << "\033[0m" << std::endl;
        }

        if (s_isFileLoggingEnabled)
        {
            std::ofstream logFile(s_logFilename, std::ios::app);
            if (logFile.is_open())
            {
                logFile << logEntry.str() << std::endl;
            }
        }
    }

    static void Info(const std::string &ip, const std::string &msg) { Record(Level::Info, ip, msg); }
    static void Warn(const std::string &ip, const std::string &msg) { Record(Level::Warning, ip, msg); }
    static void Error(const std::string &ip, const std::string &msg) { Record(Level::Error, ip, msg); }
    static void Success(const std::string &ip, const std::string &msg) { Record(Level::Success, ip, msg); }
    static void System(Level level, const std::string &msg) { Record(level, "SYSTEM", msg); }
};

std::mutex EventLogger::s_logMutex;
bool EventLogger::s_isConsoleLoggingEnabled = true;
bool EventLogger::s_isFileLoggingEnabled = false;
std::string EventLogger::s_logFilename = "file_hub_host.log";

//=============================================================================

class NetIOHandler
{
public:
    static bool TransmitPacket(SOCKET sock, const TransferPacket &packet)
    {
        int bytesSent = 0;
        const int packetSize = sizeof(TransferPacket);
        const char *buffer = reinterpret_cast<const char *>(&packet);

        while (bytesSent < packetSize)
        {
            int result = send(sock, buffer + bytesSent, packetSize - bytesSent, 0);
            if (result == SOCKET_ERROR)
            {
                std::cerr << "send() failed. Error: " << WSAGetLastError() << std::endl;
                return false;
            }
            bytesSent += result;
        }
        return true;
    }

    static bool ReceivePacket(SOCKET sock, TransferPacket &packet)
    {
        int bytesReceived = 0;
        const int packetSize = sizeof(TransferPacket);
        char *buffer = reinterpret_cast<char *>(&packet);

        while (bytesReceived < packetSize)
        {
            int result = recv(sock, buffer + bytesReceived, packetSize - bytesReceived, 0);
            if (result <= 0)
            {
                return false;
            }
            bytesReceived += result;
        }
        return true;
    }

    static bool StreamFileToSocket(SOCKET sock, const std::string &filePath)
    {
        std::ifstream file(filePath, std::ios::binary | std::ios::ate);
        if (!file.is_open())
            return false;

        std::streamsize fileSize = file.tellg();
        file.seekg(0, std::ios::beg);

        TransferPacket sizePacket;
        sizePacket.opCode = static_cast<int>(OperationCode::INITIATE_UPLOAD);
        sizePacket.payloadSize = static_cast<int>(fileSize);
        if (!TransmitPacket(sock, sizePacket))
        {
            file.close();
            return false;
        }

        char buffer[PACKET_PAYLOAD_SIZE];
        while (file.read(buffer, sizeof(buffer)))
        {
            if (send(sock, buffer, sizeof(buffer), 0) == SOCKET_ERROR)
            {
                file.close();
                return false;
            }
        }
        if (file.gcount() > 0)
        {
            if (send(sock, buffer, static_cast<int>(file.gcount()), 0) == SOCKET_ERROR)
            {
                file.close();
                return false;
            }
        }

        file.close();
        return true;
    }

    static bool StreamFileFromSocket(SOCKET sock, const std::string &filePath, long fileSize)
    {
        std::ofstream file(filePath, std::ios::binary);
        if (!file.is_open())
            return false;

        char buffer[PACKET_PAYLOAD_SIZE];
        long totalBytesReceived = 0;

        while (totalBytesReceived < fileSize)
        {
            int bytesToReceive = static_cast<int>(min(static_cast<long>(PACKET_PAYLOAD_SIZE), fileSize - totalBytesReceived));
            int bytesReceived = recv(sock, buffer, bytesToReceive, 0);
            if (bytesReceived <= 0)
            {
                file.close();
                return false;
            }
            file.write(buffer, bytesReceived);
            totalBytesReceived += bytesReceived;
        }

        file.close();
        return totalBytesReceived == fileSize;
    }
};

//=============================================================================

class FileNexusHost
{
private:
    SOCKET m_listenSocket;
    std::string m_rootDirectory;
    bool m_isRunning;

    std::string GetOperationName(int opCode)
    {
        switch (static_cast<OperationCode>(opCode))
        {
        case OperationCode::LIST_FILES:
            return "LIST_FILES";
        case OperationCode::CHANGE_DIR:
            return "CHANGE_DIR";
        case OperationCode::INITIATE_DOWNLOAD:
            return "DOWNLOAD";
        case OperationCode::INITIATE_UPLOAD:
            return "UPLOAD";
        case OperationCode::CREATE_DIR:
            return "CREATE_DIR";
        case OperationCode::REMOVE_DIR:
            return "REMOVE_DIR";
        case OperationCode::DELETE_FILE:
            return "DELETE_FILE";
        case OperationCode::GET_CURRENT_PATH:
            return "GET_PATH";
        case OperationCode::TERMINATE:
            return "TERMINATE";
        default:
            return "UNKNOWN_OP";
        }
    }

    void ProcessListRequest(const std::string &currentDir, TransferPacket &response, const std::string &clientAddr)
    {
        std::string searchPath = currentDir + "\\*";
        WIN32_FIND_DATAA findData;
        HANDLE hFind = FindFirstFileA(searchPath.c_str(), &findData);

        if (hFind == INVALID_HANDLE_VALUE)
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "Failed to read directory contents.");
            EventLogger::Error(clientAddr, "LIST failed: Cannot access " + currentDir);
            return;
        }

        std::ostringstream resultStream;
        int fileCount = 0, dirCount = 0;
        do
        {
            if (strcmp(findData.cFileName, ".") != 0 && strcmp(findData.cFileName, "..") != 0)
            {
                if (findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
                {
                    resultStream << "<DIR>  " << findData.cFileName << "\n";
                    dirCount++;
                }
                else
                {
                    resultStream << "       " << findData.cFileName << "\n";
                    fileCount++;
                }
            }
        } while (FindNextFileA(hFind, &findData));
        FindClose(hFind);

        std::string result = resultStream.str();
        response.resultCode = static_cast<int>(StatusCode::SUCCESS);
        strncpy_s(response.payload, result.c_str(), sizeof(response.payload) - 1);

        std::string relPath = PathManager::GetRelativeLocation(m_rootDirectory, currentDir);
        EventLogger::Info(clientAddr, "LIST on /" + relPath + " (" + std::to_string(dirCount) + " dirs, " + std::to_string(fileCount) + " files)");
    }

    void ProcessChangeDirRequest(std::string &currentDir, const char *target, TransferPacket &response, const std::string &clientAddr)
    {
        std::string newPath;
        if (strcmp(target, "..") == 0)
        {
            if (currentDir.length() > m_rootDirectory.length())
            {
                size_t pos = currentDir.find_last_of("\\/");
                newPath = (pos != std::string::npos) ? currentDir.substr(0, pos) : m_rootDirectory;
            }
            else
            {
                newPath = m_rootDirectory;
            }
        }
        else if (strchr(target, ':') != nullptr || target[0] == '\\' || target[0] == '/')
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Absolute paths are not allowed.");
            EventLogger::Warn(clientAddr, "CHDIR rejected: Attempted absolute path traversal.");
            return;
        }
        else
        {
            newPath = currentDir + "\\" + target;
        }

        if (!PathManager::IsPathWithinBounds(m_rootDirectory, newPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Access denied. Path is outside of storage boundary.");
            EventLogger::Warn(clientAddr, "CHDIR rejected: Attempt to access out-of-bounds path " + std::string(target));
            return;
        }

        DWORD attrs = GetFileAttributesA(newPath.c_str());
        if (attrs == INVALID_FILE_ATTRIBUTES || !(attrs & FILE_ATTRIBUTE_DIRECTORY))
        {
            response.resultCode = static_cast<int>(StatusCode::NOT_FOUND_ERROR);
            strcpy_s(response.payload, "Directory does not exist.");
            EventLogger::Warn(clientAddr, "CHDIR failed: Directory not found at " + newPath);
            return;
        }

        currentDir = newPath;
        response.resultCode = static_cast<int>(StatusCode::SUCCESS);
        std::string newRelativePath = PathManager::GetRelativeLocation(m_rootDirectory, currentDir);
        strcpy_s(response.payload, ("Directory changed to /" + newRelativePath).c_str());
        EventLogger::Info(clientAddr, "CHDIR successful. New path: /" + newRelativePath);
    }

    void ProcessDownloadRequest(const std::string &currentDir, const char *filename, TransferPacket &response, SOCKET clientSocket, const std::string &clientAddr)
    {
        std::string fullPath = currentDir + "\\" + filename;

        if (!PathManager::IsPathWithinBounds(m_rootDirectory, fullPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Access to this file is forbidden.");
            EventLogger::Error(clientAddr, "DOWNLOAD failed: Unsafe path " + std::string(filename));
            NetIOHandler::TransmitPacket(clientSocket, response);
            return;
        }

        struct _stat fileInfo;
        if (_stat(fullPath.c_str(), &fileInfo) != 0)
        {
            response.resultCode = static_cast<int>(StatusCode::NOT_FOUND_ERROR);
            strcpy_s(response.payload, "File does not exist or is inaccessible.");
            EventLogger::Warn(clientAddr, "DOWNLOAD failed: File not found " + std::string(filename));
            NetIOHandler::TransmitPacket(clientSocket, response);
            return;
        }

        response.resultCode = static_cast<int>(StatusCode::SUCCESS);
        response.payloadSize = static_cast<int>(fileInfo.st_size);
        strcpy_s(response.payload, "File transfer initiated.");

        EventLogger::Info(clientAddr, "DOWNLOAD started for " + std::string(filename) + " (" + std::to_string(fileInfo.st_size) + " bytes).");

        if (!NetIOHandler::TransmitPacket(clientSocket, response))
        {
            EventLogger::Error(clientAddr, "DOWNLOAD failed: Could not send transfer header.");
            return;
        }

        std::ifstream fileStream(fullPath, std::ios::binary);
        if (!fileStream.is_open())
        {
            EventLogger::Error(clientAddr, "DOWNLOAD failed: Could not open file " + fullPath + " for reading.");
            return;
        }

        char buffer[PACKET_PAYLOAD_SIZE];
        long long totalSent = 0;
        while (!fileStream.eof())
        {
            fileStream.read(buffer, PACKET_PAYLOAD_SIZE);
            int bytesRead = static_cast<int>(fileStream.gcount());
            if (bytesRead > 0)
            {
                if (send(clientSocket, buffer, bytesRead, 0) == SOCKET_ERROR)
                {
                    EventLogger::Error(clientAddr, "DOWNLOAD failed: Network error during file data transmission.");
                    fileStream.close();
                    return;
                }
                totalSent += bytesRead;
            }
        }
        fileStream.close();
        EventLogger::Success(clientAddr, "DOWNLOAD complete for " + std::string(filename) + ". Total sent: " + std::to_string(totalSent) + " bytes.");
    }

    void ProcessUploadRequest(const std::string &currentDir, const char *filename, TransferPacket &response, SOCKET clientSocket, const std::string &clientAddr)
    {
        std::string fullPath = currentDir + "\\" + filename;

        if (!PathManager::IsPathWithinBounds(m_rootDirectory, fullPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Upload forbidden at specified location.");
            EventLogger::Error(clientAddr, "UPLOAD failed: Unsafe path " + std::string(filename));
            return;
        }

        EventLogger::Info(clientAddr, "UPLOAD initiated for " + std::string(filename));

        response.resultCode = static_cast<int>(StatusCode::SUCCESS);
        strcpy_s(response.payload, "Ready to receive file.");
        if (!NetIOHandler::TransmitPacket(clientSocket, response))
        {
            EventLogger::Error(clientAddr, "UPLOAD failed: Could not send acknowledgment.");
            return;
        }

        TransferPacket fileInfoPacket;
        if (!NetIOHandler::ReceivePacket(clientSocket, fileInfoPacket) || static_cast<OperationCode>(fileInfoPacket.opCode) != OperationCode::INITIATE_UPLOAD)
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "Failed to receive file metadata.");
            EventLogger::Error(clientAddr, "UPLOAD failed: Invalid file metadata packet received.");
            return;
        }

        long fileSize = fileInfoPacket.payloadSize;
        EventLogger::Info(clientAddr, "Receiving " + std::string(filename) + " (" + std::to_string(fileSize) + " bytes).");

        if (NetIOHandler::StreamFileFromSocket(clientSocket, fullPath, fileSize))
        {
            response.resultCode = static_cast<int>(StatusCode::SUCCESS);
            strcpy_s(response.payload, "File uploaded successfully.");
            EventLogger::Success(clientAddr, "UPLOAD complete for " + std::string(filename));
        }
        else
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "File transfer failed during transmission.");
            EventLogger::Error(clientAddr, "UPLOAD failed: Error receiving file stream for " + std::string(filename));
            remove(fullPath.c_str());
        }
    }

    void ProcessCreateDirRequest(const std::string &currentDir, const char *dirname, TransferPacket &response, const std::string &clientAddr)
    {
        std::string fullPath = currentDir + "\\" + dirname;
        if (!PathManager::IsPathWithinBounds(m_rootDirectory, fullPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Cannot create directory outside of storage boundary.");
            EventLogger::Error(clientAddr, "MKDIR failed: Unsafe path " + std::string(dirname));
            return;
        }
        if (_mkdir(fullPath.c_str()) == 0)
        {
            response.resultCode = static_cast<int>(StatusCode::SUCCESS);
            strcpy_s(response.payload, "Directory created.");
            EventLogger::Success(clientAddr, "MKDIR complete: Created " + std::string(dirname));
        }
        else
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "Failed to create directory (it may already exist).");
            EventLogger::Error(clientAddr, "MKDIR failed for " + std::string(dirname));
        }
    }

    void ProcessRemoveDirRequest(const std::string &currentDir, const char *dirname, TransferPacket &response, const std::string &clientAddr)
    {
        std::string fullPath = currentDir + "\\" + dirname;
        if (!PathManager::IsPathWithinBounds(m_rootDirectory, fullPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Cannot remove directory outside of storage boundary.");
            EventLogger::Error(clientAddr, "RMDIR failed: Unsafe path " + std::string(dirname));
            return;
        }
        if (_rmdir(fullPath.c_str()) == 0)
        {
            response.resultCode = static_cast<int>(StatusCode::SUCCESS);
            strcpy_s(response.payload, "Directory removed.");
            EventLogger::Success(clientAddr, "RMDIR complete: Removed " + std::string(dirname));
        }
        else
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "Failed to remove directory (it may not be empty).");
            EventLogger::Error(clientAddr, "RMDIR failed for " + std::string(dirname));
        }
    }

    void ProcessDeleteFileRequest(const std::string &currentDir, const char *filename, TransferPacket &response, const std::string &clientAddr)
    {
        std::string fullPath = currentDir + "\\" + filename;
        if (!PathManager::IsPathWithinBounds(m_rootDirectory, fullPath))
        {
            response.resultCode = static_cast<int>(StatusCode::FORBIDDEN_ERROR);
            strcpy_s(response.payload, "Cannot delete file outside of storage boundary.");
            EventLogger::Error(clientAddr, "DELETE failed: Unsafe path " + std::string(filename));
            return;
        }
        if (remove(fullPath.c_str()) == 0)
        {
            response.resultCode = static_cast<int>(StatusCode::SUCCESS);
            strcpy_s(response.payload, "File deleted.");
            EventLogger::Success(clientAddr, "DELETE complete: Removed " + std::string(filename));
        }
        else
        {
            response.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
            strcpy_s(response.payload, "Failed to delete file.");
            EventLogger::Error(clientAddr, "DELETE failed for " + std::string(filename));
        }
    }

    void ProcessGetPathRequest(const std::string &currentDir, TransferPacket &response, const std::string &clientAddr)
    {
        std::string relativePath = PathManager::GetRelativeLocation(m_rootDirectory, currentDir);
        response.resultCode = static_cast<int>(StatusCode::SUCCESS);
        strcpy_s(response.payload, ("/" + relativePath).c_str());
        EventLogger::Info(clientAddr, "PWD request: " + std::string(response.payload));
    }

    void ClientSessionHandler(SOCKET clientSocket, const std::string clientAddress)
    {
        std::string sessionDirectory = m_rootDirectory;
        TransferPacket requestPacket, responsePacket;
        EventLogger::Info(clientAddress, "Client session started. Root: " + sessionDirectory);

        for (;;)
        {
            if (!NetIOHandler::ReceivePacket(clientSocket, requestPacket))
            {
                EventLogger::Warn(clientAddress, "Failed to receive packet. Ending session.");
                break;
            }

            std::string opName = GetOperationName(requestPacket.opCode);
            std::string logDetails = "Request: " + opName;
            if (strlen(requestPacket.payload) > 0)
            {
                logDetails += ", Args: " + std::string(requestPacket.payload);
            }
            EventLogger::Info(clientAddress, logDetails);

            responsePacket = TransferPacket();
            responsePacket.opCode = requestPacket.opCode;

            auto op = static_cast<OperationCode>(requestPacket.opCode);

            if (op == OperationCode::INITIATE_DOWNLOAD)
            {
                ProcessDownloadRequest(sessionDirectory, requestPacket.payload, responsePacket, clientSocket, clientAddress);
                continue;
            }
            if (op == OperationCode::INITIATE_UPLOAD)
            {
                ProcessUploadRequest(sessionDirectory, requestPacket.payload, responsePacket, clientSocket, clientAddress);
                NetIOHandler::TransmitPacket(clientSocket, responsePacket);
                continue;
            }

            switch (op)
            {
            case OperationCode::LIST_FILES:
                ProcessListRequest(sessionDirectory, responsePacket, clientAddress);
                break;
            case OperationCode::CHANGE_DIR:
                ProcessChangeDirRequest(sessionDirectory, requestPacket.payload, responsePacket, clientAddress);
                break;
            case OperationCode::CREATE_DIR:
                ProcessCreateDirRequest(sessionDirectory, requestPacket.payload, responsePacket, clientAddress);
                break;
            case OperationCode::REMOVE_DIR:
                ProcessRemoveDirRequest(sessionDirectory, requestPacket.payload, responsePacket, clientAddress);
                break;
            case OperationCode::DELETE_FILE:
                ProcessDeleteFileRequest(sessionDirectory, requestPacket.payload, responsePacket, clientAddress);
                break;
            case OperationCode::GET_CURRENT_PATH:
                ProcessGetPathRequest(sessionDirectory, responsePacket, clientAddress);
                break;
            case OperationCode::TERMINATE:
                responsePacket.resultCode = static_cast<int>(StatusCode::SUCCESS);
                strcpy_s(responsePacket.payload, "Goodbye!");
                NetIOHandler::TransmitPacket(clientSocket, responsePacket);
                EventLogger::Info(clientAddress, "Client terminated the session.");
                goto session_end;
            default:
                responsePacket.resultCode = static_cast<int>(StatusCode::REQUEST_ERROR);
                strcpy_s(responsePacket.payload, "Invalid operation code received.");
                EventLogger::Warn(clientAddress, "Received unknown operation code: " + std::to_string(requestPacket.opCode));
                break;
            }

            if (!NetIOHandler::TransmitPacket(clientSocket, responsePacket))
            {
                EventLogger::Error(clientAddress, "Failed to send response packet. Ending session.");
                break;
            }
        }

    session_end:
        closesocket(clientSocket);
        EventLogger::Info(clientAddress, "Client session ended.");
    }

public:
    FileNexusHost() : m_isRunning(false), m_listenSocket(INVALID_SOCKET)
    {
        m_rootDirectory = HOST_ROOT_PATH;
        if (!PathManager::EnsureDirectoryExists(m_rootDirectory))
        {
            throw std::runtime_error("Fatal: Could not create the host's root storage directory.");
        }
    }

    ~FileNexusHost()
    {
        CeaseOperations();
    }

    bool Prepare(int port = DEFAULT_LISTEN_PORT)
    {
        WSADATA wsa;
        if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
        {
            std::cerr << "WSAStartup failed. Error Code: " << WSAGetLastError() << std::endl;
            return false;
        }

        m_listenSocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (m_listenSocket == INVALID_SOCKET)
        {
            std::cerr << "Socket creation failed. Error: " << WSAGetLastError() << std::endl;
            WSACleanup();
            return false;
        }

        int opt = 1;
        setsockopt(m_listenSocket, SOL_SOCKET, SO_REUSEADDR, (char *)&opt, sizeof(opt));

        sockaddr_in serverAddr;
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(port);

        if (bind(m_listenSocket, (sockaddr *)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR)
        {
            std::cerr << "Bind failed. Error: " << WSAGetLastError() << std::endl;
            closesocket(m_listenSocket);
            WSACleanup();
            return false;
        }

        if (listen(m_listenSocket, SOMAXCONN) == SOCKET_ERROR)
        {
            std::cerr << "Listen failed. Error: " << WSAGetLastError() << std::endl;
            closesocket(m_listenSocket);
            WSACleanup();
            return false;
        }
        return true;
    }

    void BeginAccepting(int port = DEFAULT_LISTEN_PORT)
    {
        if (!Prepare(port))
        {
            return;
        }

        m_isRunning = true;
        EventLogger::System(EventLogger::Level::Success, "File Nexus Host is now online, listening on port " + std::to_string(port));
        EventLogger::System(EventLogger::Level::Info, "Storage root is located at: " + m_rootDirectory);
        std::cout << "\n--- Host Activity Log ---" << std::endl;

        while (m_isRunning)
        {
            sockaddr_in clientAddrInfo;
            int clientAddrLen = sizeof(clientAddrInfo);
            SOCKET clientConnection = accept(m_listenSocket, (sockaddr *)&clientAddrInfo, &clientAddrLen);

            if (clientConnection == INVALID_SOCKET)
            {
                if (m_isRunning)
                {
                    EventLogger::System(EventLogger::Level::Error, "accept() failed with error: " + std::to_string(WSAGetLastError()));
                }
                continue;
            }

            char clientIPStr[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &clientAddrInfo.sin_addr, clientIPStr, INET_ADDRSTRLEN);
            int clientPort = ntohs(clientAddrInfo.sin_port);
            std::string clientAddress = std::string(clientIPStr) + ":" + std::to_string(clientPort);

            EventLogger::Success(clientAddress, "Connection established.");

            std::thread clientThread(&FileNexusHost::ClientSessionHandler, this, clientConnection, clientAddress);
            clientThread.detach();
        }
    }

    void CeaseOperations()
    {
        m_isRunning = false;
        if (m_listenSocket != INVALID_SOCKET)
        {
            closesocket(m_listenSocket);
            m_listenSocket = INVALID_SOCKET;
        }
        WSACleanup();
        EventLogger::System(EventLogger::Level::Info, "File Nexus Host has shut down.");
    }
};

//=============================================================================

class FileNexusClient
{
private:
    SOCKET m_serverConnection;
    bool m_isConnected;
    std::string m_remotePath;
    std::string m_localDirectory;

    void PrintPrompt()
    {
        std::cout << "\nnexus-client [" << m_remotePath << "]> ";
        std::cout.flush();
    }

    void RefreshRemotePath()
    {
        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::GET_CURRENT_PATH);
        if (NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            TransferPacket response;
            if (NetIOHandler::ReceivePacket(m_serverConnection, response) && response.resultCode == static_cast<int>(StatusCode::SUCCESS))
            {
                m_remotePath = response.payload;
            }
        }
    }

    void IssueListCommand()
    {
        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::LIST_FILES);
        if (!NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            std::cout << "Error: Could not send command." << std::endl;
            return;
        }

        TransferPacket response;
        if (NetIOHandler::ReceivePacket(m_serverConnection, response))
        {
            if (response.resultCode == static_cast<int>(StatusCode::SUCCESS))
            {
                std::cout << "Host Directory Listing [" << m_remotePath << "]:\n"
                          << response.payload << std::endl;
            }
            else
            {
                std::cout << "Host Error: " << response.payload << std::endl;
            }
        }
        else
        {
            std::cout << "Error: Failed to receive response from host." << std::endl;
        }
    }

    void IssueChangeDirCommand(const std::string &dir)
    {
        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::CHANGE_DIR);
        strcpy_s(request.payload, dir.c_str());
        if (!NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            std::cout << "Error: Could not send command." << std::endl;
            return;
        }

        TransferPacket response;
        if (NetIOHandler::ReceivePacket(m_serverConnection, response))
        {
            std::cout << response.payload << std::endl;
            if (response.resultCode == static_cast<int>(StatusCode::SUCCESS))
            {
                RefreshRemotePath();
            }
        }
        else
        {
            std::cout << "Error: Failed to receive response from host." << std::endl;
        }
    }

    void IssueDownloadCommand(const std::string &filename)
    {
        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::INITIATE_DOWNLOAD);
        strcpy_s(request.payload, filename.c_str());
        if (!NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            std::cout << "Error: Could not send download request." << std::endl;
            return;
        }

        TransferPacket response;
        if (!NetIOHandler::ReceivePacket(m_serverConnection, response))
        {
            std::cout << "Error: Failed to receive transfer header from host." << std::endl;
            return;
        }

        if (response.resultCode == static_cast<int>(StatusCode::SUCCESS))
        {
            std::string localFilePath = m_localDirectory + "\\" + filename;
            long fileSize = response.payloadSize;
            std::cout << "Downloading '" << filename << "' (" << fileSize << " bytes) to '" << localFilePath << "'..." << std::endl;
            if (NetIOHandler::StreamFileFromSocket(m_serverConnection, localFilePath, fileSize))
            {
                std::cout << "Download completed successfully." << std::endl;
            }
            else
            {
                std::cout << "Download failed during transmission." << std::endl;
            }
        }
        else
        {
            std::cout << "Host Error: " << response.payload << std::endl;
        }
    }

    void IssueUploadCommand(const std::string &filename)
    {
        std::string localFilePath = m_localDirectory + "\\" + filename;
        if (_access(localFilePath.c_str(), 0) != 0)
        {
            std::cout << "Error: Local file not found at " << localFilePath << std::endl;
            return;
        }

        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::INITIATE_UPLOAD);
        strcpy_s(request.payload, filename.c_str());
        if (!NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            std::cout << "Error: Could not send upload request." << std::endl;
            return;
        }

        TransferPacket ack;
        if (!NetIOHandler::ReceivePacket(m_serverConnection, ack) || ack.resultCode != static_cast<int>(StatusCode::SUCCESS))
        {
            std::cout << "Host Error: " << (ack.payloadSize > 0 ? ack.payload : "Host is not ready to receive the file.") << std::endl;
            return;
        }

        std::cout << "Host is ready. Uploading '" << filename << "' from '" << m_localDirectory << "'..." << std::endl;

        if (!NetIOHandler::StreamFileToSocket(m_serverConnection, localFilePath))
        {
            std::cout << "Upload failed: An error occurred during file transmission." << std::endl;
            return;
        }

        TransferPacket finalResponse;
        if (NetIOHandler::ReceivePacket(m_serverConnection, finalResponse))
        {
            std::cout << "Host Response: " << finalResponse.payload << std::endl;
        }
        else
        {
            std::cout << "Upload likely succeeded, but failed to get final confirmation from host." << std::endl;
        }
    }

    void IssueGenericCommand(OperationCode op, const std::string &arg)
    {
        TransferPacket request;
        request.opCode = static_cast<int>(op);
        strcpy_s(request.payload, arg.c_str());
        if (!NetIOHandler::TransmitPacket(m_serverConnection, request))
        {
            std::cout << "Error: Could not send command." << std::endl;
            return;
        }

        TransferPacket response;
        if (NetIOHandler::ReceivePacket(m_serverConnection, response))
        {
            std::cout << "Host Response: " << response.payload << std::endl;
        }
        else
        {
            std::cout << "Error: Failed to receive response from host." << std::endl;
        }
    }

    void IssueQuitCommand()
    {
        TransferPacket request;
        request.opCode = static_cast<int>(OperationCode::TERMINATE);
        NetIOHandler::TransmitPacket(m_serverConnection, request);
    }

public:
    FileNexusClient() : m_isConnected(false), m_serverConnection(INVALID_SOCKET), m_remotePath("/")
    {
        m_localDirectory = CLIENT_ROOT_PATH;
        if (!PathManager::EnsureDirectoryExists(m_localDirectory))
        {
            throw std::runtime_error("Fatal: Could not create the client's local storage directory.");
        }
    }

    ~FileNexusClient()
    {
        if (m_isConnected)
            EndConnection();
    }

    bool EstablishConnection(const std::string &hostIP, int port = DEFAULT_LISTEN_PORT)
    {
        WSADATA wsa;
        if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0)
        {
            std::cerr << "WSAStartup failed." << std::endl;
            return false;
        }

        m_serverConnection = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if (m_serverConnection == INVALID_SOCKET)
        {
            std::cerr << "Socket creation failed." << std::endl;
            WSACleanup();
            return false;
        }

        sockaddr_in hostAddr;
        hostAddr.sin_family = AF_INET;
        inet_pton(AF_INET, hostIP.c_str(), &hostAddr.sin_addr);
        hostAddr.sin_port = htons(port);

        if (connect(m_serverConnection, (sockaddr *)&hostAddr, sizeof(hostAddr)) == SOCKET_ERROR)
        {
            std::cerr << "Failed to connect to host. Error: " << WSAGetLastError() << std::endl;
            closesocket(m_serverConnection);
            WSACleanup();
            return false;
        }

        m_isConnected = true;
        std::cout << "Successfully connected to host at " << hostIP << ":" << port << std::endl;
        std::cout << "Your local files are in: '" << m_localDirectory << "'" << std::endl;

        RefreshRemotePath();
        return true;
    }

    void EndConnection()
    {
        if (m_isConnected)
        {
            IssueQuitCommand();
            m_isConnected = false;
        }
        if (m_serverConnection != INVALID_SOCKET)
        {
            closesocket(m_serverConnection);
            m_serverConnection = INVALID_SOCKET;
        }
        WSACleanup();
    }

    void StartInteractiveSession()
    {
        if (!m_isConnected)
        {
            std::cout << "Client is not connected to a host." << std::endl;
            return;
        }

        std::cout << "\n--- Welcome to the File Nexus Client ---" << std::endl;
        std::cout << "Available commands: dir, enter <dir>, download <file>, upload <file>, newdir <dir>, deldir <dir>, erase <file>, path, exit" << std::endl;

        std::string line;
        for (;;)
        {
            PrintPrompt();
            std::getline(std::cin, line);
            if (line.empty())
                continue;

            std::istringstream iss(line);
            std::string command, argument;
            iss >> command >> argument;

            if (command == "exit" || command == "quit")
            {
                break;
            }
            else if (command == "dir" || command == "ls")
            {
                IssueListCommand();
            }
            else if (command == "enter" || command == "cd")
            {
                if (argument.empty())
                    std::cout << "Usage: enter <directory_name>" << std::endl;
                else
                    IssueChangeDirCommand(argument);
            }
            else if (command == "download" || command == "get")
            {
                if (argument.empty())
                    std::cout << "Usage: download <file_name>" << std::endl;
                else
                    IssueDownloadCommand(argument);
            }
            else if (command == "upload" || command == "put")
            {
                if (argument.empty())
                    std::cout << "Usage: upload <file_name>" << std::endl;
                else
                    IssueUploadCommand(argument);
            }
            else if (command == "newdir" || command == "mkdir")
            {
                if (argument.empty())
                    std::cout << "Usage: newdir <directory_name>" << std::endl;
                else
                    IssueGenericCommand(OperationCode::CREATE_DIR, argument);
            }
            else if (command == "deldir" || command == "rmdir")
            {
                if (argument.empty())
                    std::cout << "Usage: deldir <directory_name>" << std::endl;
                else
                    IssueGenericCommand(OperationCode::REMOVE_DIR, argument);
            }
            else if (command == "erase" || command == "del")
            {
                if (argument.empty())
                    std::cout << "Usage: erase <file_name>" << std::endl;
                else
                    IssueGenericCommand(OperationCode::DELETE_FILE, argument);
            }
            else if (command == "path" || command == "pwd")
            {
                RefreshRemotePath();
                std::cout << "Host remote path: " << m_remotePath << std::endl;
            }
            else
            {
                std::cout << "Unknown command: '" << command << "'" << std::endl;
            }
        }
    }
};

//=============================================================================

void LaunchHostMode()
{
    std::cout << "--- File Nexus Host ---" << std::endl;
    try
    {
        std::string portInput;
        std::cout << "Enter listening port (default: " << DEFAULT_LISTEN_PORT << "): ";
        std::cout.flush();
        std::getline(std::cin, portInput);
        int port = portInput.empty() ? DEFAULT_LISTEN_PORT : std::stoi(portInput);

        std::string logInput;
        std::cout << "Enable logging to file? (y/n, default: n): ";
        std::cout.flush();
        std::getline(std::cin, logInput);
        bool enableLogFile = (!logInput.empty() && (logInput[0] == 'y' || logInput[0] == 'Y'));

        std::string logFilename = "nexus_host_" + std::to_string(port) + ".log";
        EventLogger::EnableFileLogging(enableLogFile, logFilename);
        if (enableLogFile)
        {
            std::cout << "File logging is enabled. Output will be saved to " << logFilename << std::endl;
        }

        FileNexusHost host;
        host.BeginAccepting(port);
    }
    catch (const std::exception &e)
    {
        std::cerr << "A critical error occurred while running the host: " << e.what() << std::endl;
    }
}

void LaunchClientMode()
{
    std::cout << "--- File Nexus Client ---" << std::endl;
    try
    {
        std::string ipInput;
        std::cout << "Enter host IP address (default: 127.0.0.1): ";
        std::cout.flush();
        std::getline(std::cin, ipInput);
        if (ipInput.empty())
            ipInput = "127.0.0.1";

        std::string portInput;
        std::cout << "Enter host port (default: " << DEFAULT_LISTEN_PORT << "): ";
        std::cout.flush();
        std::getline(std::cin, portInput);
        int port = portInput.empty() ? DEFAULT_LISTEN_PORT : std::stoi(portInput);

        FileNexusClient client;
        if (client.EstablishConnection(ipInput, port))
        {
            client.StartInteractiveSession();
        }
        std::cout << "Client session has ended." << std::endl;
    }
    catch (const std::exception &e)
    {
        std::cerr << "A critical error occurred while running the client: " << e.what() << std::endl;
    }
}

int main()
{
    std::cout << "================================================" << std::endl;
    std::cout << "     Network File Hub System (v1.0)" << std::endl;
    std::cout << "================================================" << std::endl;
    std::cout << "  1. Launch Host Mode (Storage: " << HOST_ROOT_PATH << ")" << std::endl;
    std::cout << "  2. Launch Client Mode (Storage: " << CLIENT_ROOT_PATH << ")" << std::endl;
    std::cout << "Please select an option (1 or 2): ";
    std::cout.flush();

    int choice = 0;
    std::cin >> choice;

    switch (choice)
    {
    case 1:
        LaunchHostMode();
        break;
    case 2:
        LaunchClientMode();
        break;
    default:
        std::cout << "Invalid choice. Exiting." << std::endl;
        break;
    }

    return 0;
}
