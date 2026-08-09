import { IsString, MinLength, Matches } from "class-validator";

export class AcceptInviteDto {
  @IsString() token: string;
  @IsString() @MinLength(2) name: string;
  @IsString()
  @MinLength(8)
  @Matches(/(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message: "Password must include upper, lower, and a number",
  })
  password: string;
}
