export class SafeUserDto {
  id: number;
  username: string;
  email: string;

  constructor(user: any) {
    this.id = user.id;
    this.username = user.username;
    this.email = user.email;
  }
}
