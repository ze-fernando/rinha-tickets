import { Module } from '@nestjs/common';
import { TicketsModule } from './tickets/tickets.module.js';

@Module({
  imports: [TicketsModule],
  controllers: [],
  providers: [],
})
export class AppModule {}
