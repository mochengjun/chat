// Google Identity Services 类型声明
interface GoogleIdentityServicesLibrary {
  accounts: {
    id: {
      initialize: (config: {
        client_id: string;
        callback: (response: { credential: string }) => void;
      }) => void;
      prompt: (callback: (notification: {
        isNotDisplayed: () => boolean;
        isSkippedMoment: () => boolean;
      }) => void) => void;
      renderButton: (
        element: HTMLElement,
        config: {
          type: 'standard' | 'icon';
          theme?: 'outline' | 'filled_blue' | 'filled_black';
          size?: 'large' | 'medium' | 'small';
          text?: 'signin_with' | 'signup_with' | 'continue_with';
        }
      ) => void;
      revoke: (
        hint: string,
        callback: (response: { successful: boolean }) => void
      ) => void;
    };
  };
}

declare global {
  interface Window {
    google?: GoogleIdentityServicesLibrary;
  }
}

export {};
