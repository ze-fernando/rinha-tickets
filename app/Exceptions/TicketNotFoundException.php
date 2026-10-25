<?php

namespace App\Exceptions;

use Symfony\Component\HttpFoundation\Response;

final class TicketNotFoundException extends ApiException
{
    public function __construct()
    {
        parent::__construct(
            message: 'Chamado não encontrado',
            errorCode: 'TICKET_NOT_FOUND',
            statusCode: Response::HTTP_NOT_FOUND,
        );
    }
}
