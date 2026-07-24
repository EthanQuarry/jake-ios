export type JakeValue = string | number | boolean | null;
export type JakeProperties = Record<string, JakeValue>;

export interface JakeConfiguration {
  workspaceId: string;
  publicKey: string;
  messengerUrl?: string;
}

export interface JakeSubscription {
  remove(): void;
}

export declare const JakeEvent: Readonly<{
  unreadCountChanged: 'jakeUnreadCountChanged';
  authenticationExpired: 'jakeAuthenticationExpired';
  error: 'jakeError';
}>;

export declare const Jake: {
  configure(options: JakeConfiguration): Promise<void>;
  authenticate(userId: string, token: string): Promise<void>;
  present(): Promise<void>;
  dismiss(): Promise<void>;
  logout(): Promise<void>;
  track(event: string, properties?: JakeProperties): Promise<void>;
  setUserAttributes(attributes: JakeProperties): Promise<void>;
  setPushToken(token: string): Promise<void>;
  getUnreadCount(): Promise<number>;
  addEventListener(
    event: (typeof JakeEvent)[keyof typeof JakeEvent],
    listener: (payload: Readonly<Record<string, unknown>>) => void,
  ): JakeSubscription;
};
