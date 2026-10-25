<?php

namespace App\Http\Requests;

use App\Enums\TicketStatus;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class TicketRequest extends FormRequest
{
    


    public function authorize(): bool
    {
        return true;
    }

    




    public function rules(): array
    {
        return [
            'title' => ['required', 'string', 'max:255'],
            'description' => ['required', 'string'],
            'sector' => ['required', 'string', 'max:255'],
            'status' => ['sometimes', 'string', Rule::enum(TicketStatus::class)],
        ];
    }

    




    public function messages(): array
    {
        return [
            'title.required' => 'O título é obrigatório.',
            'title.string' => 'O título deve ser um texto.',
            'title.max' => 'O título deve ter no máximo 255 caracteres.',
            'description.required' => 'A descrição é obrigatória.',
            'description.string' => 'A descrição deve ser um texto.',
            'sector.required' => 'O setor é obrigatório.',
            'sector.string' => 'O setor deve ser um texto.',
            'sector.max' => 'O setor deve ter no máximo 255 caracteres.',
            'status.enum' => 'O status deve ser open, in_progress ou closed.',
        ];
    }

    


    protected function prepareForValidation(): void
    {
        if (is_string($this->input('status'))) {
            $this->merge([
                'status' => strtolower($this->input('status')),
            ]);
        }
    }
}
