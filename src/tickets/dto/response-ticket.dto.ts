import { Status } from '../../generated/prisma/enums.js';

import { IsString, IsEnum, IsOptional } from 'class-validator';

export class ResponseTicketDto {
  id: number;
  title: string;
  @IsString()
  description: string;
  @IsString()
  sector: string;
  @IsEnum(Status)
  @IsOptional()
  status: Status;
  @IsOptional()
  finishedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
