import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Piece } from './entities/piece.entity';
import { UpdatePieceDto } from './dto/update-piece.dto';

@Injectable()
export class PieceService {
	constructor(
		@InjectRepository(Piece)
		private readonly pieceRepository: Repository<Piece>,
	) {}

	async update(id: number, userId: number, dto: UpdatePieceDto) {
		const piece = await this.pieceRepository.findOne({
			where: { id },
			relations: ['gabarit', 'gabarit.user', 'fabric'],
		});
		if (!piece) throw new NotFoundException('Piece not found');
		if (!piece.gabarit || (piece.gabarit as any).user?.id !== userId) {
			throw new ForbiddenException('You do not have access to this piece');
		}

		// Only allow updating name and NumberOfPieces
		if (dto.name !== undefined) piece.name = dto.name;
		if (dto.NumberOfPieces !== undefined) piece.NumberOfPieces = dto.NumberOfPieces;
        if (dto.fabricId) piece.fabric = { id: dto.fabricId } as any;
		const saved = await this.pieceRepository.save(piece);
		return {
			id: saved.id,
			name: saved.name ?? null,
			outline: saved.outline,
			area: saved.area,
			NumberOfPieces: saved.NumberOfPieces ?? 1,
			// Ensure fabricId is returned if present on the relation
			fabricId: (saved as any).fabric?.id ?? null,
			createdAt: saved.createdAt,
			updatedAt: saved.updatedAt,
			deletedAt: saved.deletedAt,
		};
	}
}
