import { getAccessToken } from './auth';
import type { UserSession } from './auth';

export interface ChatMessage {
  id: string;
  content: string;
  type: 'text' | 'image';
  sender: string;
  senderName: string;
  timestamp: string;
  chatId: string;
}

export interface WebSocketManager {
  connect(): Promise<void>;
  disconnect(): void;
  sendMessage(message: Omit<ChatMessage, 'id' | 'timestamp'>): void;
  joinRoom(roomId: string, type: 'private' | 'group'): void;
  onMessage(callback: (message: ChatMessage) => void): void;
  onConnect(callback: () => void): void;
  onDisconnect(callback: () => void): void;
  onError(callback: (error: any) => void): void;
  isConnected(): boolean;
}

export function createWebSocketManager(session: UserSession): WebSocketManager {
  let socket: any = null;
  let connected = false;
  let messageCallbacks: ((message: ChatMessage) => void)[] = [];
  let connectCallbacks: (() => void)[] = [];
  let disconnectCallbacks: (() => void)[] = [];
  let errorCallbacks: ((error: any) => void)[] = [];

  return {
    async connect() {
      try {
        const token = await getAccessToken();
        if (!token) {
          throw new Error('未找到访问令牌');
        }

        // 模拟WebSocket连接
        // 实际项目中这里会使用socket.io-client
        socket = {
          emit: (event: string, data: any) => {
            console.log('WebSocket emit:', event, data);
            
            // 模拟服务器响应
            if (event === 'message') {
              setTimeout(() => {
                const response: ChatMessage = {
                  ...data,
                  id: Date.now().toString(),
                  timestamp: new Date().toISOString()
                };
                messageCallbacks.forEach(cb => cb(response));
              }, 100);
            }
          },
          
          on: (event: string, callback: Function) => {
            console.log('WebSocket on:', event);
          },
          
          disconnect: () => {
            connected = false;
            disconnectCallbacks.forEach(cb => cb());
          }
        };

        connected = true;
        connectCallbacks.forEach(cb => cb());
        
      } catch (error) {
        errorCallbacks.forEach(cb => cb(error));
        throw error;
      }
    },

    disconnect() {
      if (socket) {
        socket.disconnect();
        socket = null;
        connected = false;
      }
    },

    sendMessage(message) {
      if (!socket || !connected) {
        throw new Error('WebSocket未连接');
      }
      
      const fullMessage = {
        ...message,
        id: Date.now().toString(),
        timestamp: new Date().toISOString()
      };
      
      socket.emit('message', fullMessage);
    },

    joinRoom(roomId, type) {
      if (!socket || !connected) {
        throw new Error('WebSocket未连接');
      }
      
      socket.emit('join-room', { roomId, type });
    },

    onMessage(callback) {
      messageCallbacks.push(callback);
    },

    onConnect(callback) {
      connectCallbacks.push(callback);
    },

    onDisconnect(callback) {
      disconnectCallbacks.push(callback);
    },

    onError(callback) {
      errorCallbacks.push(callback);
    },

    isConnected() {
      return connected;
    }
  };
} 