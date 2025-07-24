import { Test, TestingModule } from '@nestjs/testing';
import { GabaritService } from './gabarit.service';

describe('GabaritService', () => {
  let service: GabaritService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [GabaritService],
    }).compile();

    service = module.get<GabaritService>(GabaritService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
