import { Injectable } from '@nestjs/common';
import { ResponseTicketDto } from './dto/response-ticket.dto.js';
import { Status } from '../generated/prisma/enums.js';
import { CreateTicketDto } from './dto/create-ticket.dto.js';
import { TicketAlreadyExists } from './exceptions/ticket-already-exists.exception.js';
import { TicketNotFound } from './exceptions/ticket-not-found.exception.js';
import { PrismaService } from '../prisma.service.js';

@Injectable()
export class TicketsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<ResponseTicketDto[]> {
    return this.prisma.ticket.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOpen(): Promise<ResponseTicketDto[]> {
    return this.prisma.ticket.findMany({
      where: {
        status: Status.OPEN,
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findById(ticket_id: number): Promise<ResponseTicketDto> {
    const ticket = await this.prisma.ticket.findFirst({
      where: {
        id: ticket_id,
      },
    });

    if (!ticket) {
      throw new TicketNotFound();
    }

    return ticket;
  }

  async create(ticket: CreateTicketDto): Promise<ResponseTicketDto> {
    const ticket_exists = await this.prisma.ticket.findFirst({
      where: {
        title: ticket.title,
      },
    });

    if (ticket_exists) {
      throw new TicketAlreadyExists();
    }

    return await this.prisma.ticket.create({ data: ticket });
  }

  async update(
    ticket_id: number,
    ticket: CreateTicketDto,
  ): Promise<ResponseTicketDto> {
    const ticket_exists = await this.prisma.ticket.findUnique({
      where: {
        id: ticket_id,
      },
    });

    if (!ticket_exists) {
      throw new TicketNotFound();
    }

    return await this.prisma.ticket.update({
      where: { id: ticket_id },
      data: {
        title: ticket.title,
        description: ticket.description,
        sector: ticket.sector,
        status: ticket.status,
        finishedAt:
          ticket.status === Status.CLOSED
            ? (ticket_exists.finishedAt ?? new Date())
            : null,
      },
    });
  }

  async finish(ticket_id: number): Promise<ResponseTicketDto> {
    const ticket_exists = await this.prisma.ticket.findUnique({
      where: {
        id: ticket_id,
      },
    });

    if (!ticket_exists) {
      throw new TicketNotFound();
    }

    return await this.prisma.ticket.update({
      where: { id: ticket_id },
      data: {
        status: Status.CLOSED,
        finishedAt: new Date(Date.now()),
      },
    });
  }
}
