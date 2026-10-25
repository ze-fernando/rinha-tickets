<?php

namespace App\Http\Controllers;

use App\DTOs\TicketData;
use App\Http\Requests\TicketRequest;
use App\Http\Resources\TicketResource;
use App\Services\TicketService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Symfony\Component\HttpFoundation\Response;

class TicketController extends Controller
{
    public function __construct(private readonly TicketService $ticketService) {}

    public function findAll(): AnonymousResourceCollection
    {
        return TicketResource::collection($this->ticketService->findAll());
    }

    public function findOpen(): AnonymousResourceCollection
    {
        return TicketResource::collection($this->ticketService->findOpen());
    }

    public function findById(int $ticketId): TicketResource
    {
        return new TicketResource($this->ticketService->findById($ticketId));
    }

    public function create(TicketRequest $request): JsonResponse
    {
        $ticket = $this->ticketService->create(
            TicketData::fromArray($request->validated()),
        );

        return (new TicketResource($ticket))
            ->response()
            ->setStatusCode(Response::HTTP_CREATED);
    }

    public function update(TicketRequest $request, int $ticketId): TicketResource
    {
        $ticket = $this->ticketService->update(
            $ticketId,
            TicketData::fromArray($request->validated()),
        );

        return new TicketResource($ticket);
    }

    public function finish(int $ticketId): TicketResource
    {
        return new TicketResource($this->ticketService->finish($ticketId));
    }
}
