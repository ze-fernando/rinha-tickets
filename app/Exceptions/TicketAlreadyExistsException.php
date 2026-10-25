<?php

namespace App\Exceptions;

use Symfony\Component\HttpFoundation\Response;

final class TicketAlreadyExistsException extends ApiException
{
    public function __construct()
    {
        parent::__construct(
            message: 'Chamado já em aberto',
            errorCode: 'TICKET_ALREADY_EXISTS',
            statusCode: Response::HTTP_CONFLICT,
        );
    }
}
