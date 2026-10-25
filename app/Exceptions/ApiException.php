<?php

namespace App\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

abstract class ApiException extends Exception
{
    public function __construct(
        string $message,
        private readonly string $errorCode,
        private readonly int $statusCode,
    ) {
        parent::__construct($message);
    }

   public function render(Request $request): JsonResponse
    {
        return response()->json([
            'code' => $this->errorCode,
            'message' => $this->getMessage(),
        ], $this->statusCode);
    }
}
