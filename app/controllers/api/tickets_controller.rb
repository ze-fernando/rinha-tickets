module Api
  class TicketsController < ApplicationController
    def index
      render json: TicketsService.find_all
    end

    def open
      render json: TicketsService.find_open
    end

    def show
      render json: TicketsService.find_by_id(params[:id])
    end

    def create
      render json: TicketsService.create(ticket_data), status: :created
    end

    def update
      render json: TicketsService.update(params[:id], ticket_data)
    end

    def finish
      render json: TicketsService.finish(params[:id])
    end

    private

    def ticket_data
      data = TicketData.from_params(ticket_params)
      raise ValidationError.new(data.errors.to_hash) unless data.valid?

      data
    end

    def ticket_params
      params
        .to_unsafe_h
        .slice("title", "description", "sector", "status")
        .symbolize_keys
    end
  end
end
