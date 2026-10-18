import { HttpException, HttpStatus } from '@nestjs/common';

export class TicketNotFound extends HttpException {
  constructor() {
    super(
      {
        code: 'TICKET_NOT_FOUND',
        message: `Chamado não encontrado`,
      },
      HttpStatus.NOT_FOUND,
    );
  }
}
