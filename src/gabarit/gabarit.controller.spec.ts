import { Test, TestingModule } from '@nestjs/testing';
import { GabaritController } from './gabarit.controller';
import { GabaritService } from './gabarit.service';

describe('GabaritController', () => {
  let controller: GabaritController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [GabaritController],
      providers: [GabaritService],
    }).compile();

    controller = module.get<GabaritController>(GabaritController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
