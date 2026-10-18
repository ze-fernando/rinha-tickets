import { HttpException, HttpStatus } from '@nestjs/common';

export class TicketAlreadyExists extends HttpException {
  constructor() {
    super(
      {
        code: 'TICKET_ALREADY_EXISTS',
        message: `Chamado já em aberto`,
      },
      HttpStatus.CONFLICT,
    );
  }
}
