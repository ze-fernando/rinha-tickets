import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Put,
} from '@nestjs/common';
import { TicketsService } from './tickets.service.js';
import { ResponseTicketDto } from './dto/response-ticket.dto.js';
import { CreateTicketDto } from './dto/create-ticket.dto.js';

@Controller('api/tickets')
export class TicketsController {
  constructor(private readonly ticketsService: TicketsService) {}

  @Get('all')
  findAll(): Promise<ResponseTicketDto[]> {
    return this.ticketsService.findAll();
  }

  @Get('open')
  findOpen(): Promise<ResponseTicketDto[]> {
    return this.ticketsService.findOpen();
  }

  @Get(':id')
  findById(@Param('id', ParseIntPipe) id: number): Promise<ResponseTicketDto> {
    return this.ticketsService.findById(id);
  }

  @Post('create')
  create(@Body() dto: CreateTicketDto): Promise<ResponseTicketDto> {
    return this.ticketsService.create(dto);
  }

  @Put(':id/update')
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: CreateTicketDto,
  ): Promise<ResponseTicketDto> {
    return this.ticketsService.update(id, dto);
  }

  @Put(':id/finish')
  finish(@Param('id', ParseIntPipe) id: number): Promise<ResponseTicketDto> {
    return this.ticketsService.finish(id);
  }
}
