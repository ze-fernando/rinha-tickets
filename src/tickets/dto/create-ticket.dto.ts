import { Status } from '../../generated/prisma/enums.js';
import { IsString, IsEnum, IsOptional } from 'class-validator';
import { Transform } from 'class-transformer';

export class CreateTicketDto {
  @IsString()
  title: string;
  @IsString()
  description: string;
  @IsString()
  sector: string;
  @Transform(({ value }) =>
    typeof value === 'string' ? value.toUpperCase() : value,
  )
  @IsEnum(Status)
  @IsOptional()
  status: Status = Status.OPEN;
}
