import { getAccessToken } from './auth';
import type { UserSession } from './auth';
import { io } from 'socket.io-client';

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

        socket = io(`${import.meta.env.VITE_API_BASE_URL || ''}/api/chat`, {
          auth: {
            token: token
          },
          transports: ['websocket', 'polling']
        });

        socket.on('connect', () => {
          connected = true;
          console.log('WebSocket connected');
          connectCallbacks.forEach(cb => cb());
        });

        socket.on('disconnect', () => {
          connected = false;
          console.log('WebSocket disconnected');
          disconnectCallbacks.forEach(cb => cb());
        });

        socket.on('error', (error: any) => {
          console.error('WebSocket error:', error);
          errorCallbacks.forEach(cb => cb(error));
        });

        socket.on('new_message', (message: ChatMessage) => {
          messageCallbacks.forEach(cb => cb(message));
        });

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
      
      socket.emit('send_message', {
        chat_id: message.chatId,
        content: message.content,
        type: message.type,
        sender_id: session.user.id,
        sender_name: session.user.nickname || session.user.email
      });
    },

    joinRoom(roomId, type) {
      if (!socket || !connected) {
        throw new Error('WebSocket未连接');
      }
      
      socket.emit('join_room', { room_id: roomId, room_type: type });
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