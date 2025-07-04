export interface Credentials {
  username: string; // Changed from username to match form
  email: string;
  password: string;
  code: string;
}

export interface CredentialsLogin {
  email: string;
  password: string;
}
