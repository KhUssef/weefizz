import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { User } from './entities/user.entity';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

@Injectable()
export class UserService {
  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,) {}

  async create(createUserDto: CreateUserDto): Promise<User> {
    const user = this.userRepository.create(createUserDto);
    try {
      return await this.userRepository.save(user);
    } catch (err: any) {
      // Handle unique constraint violation for email
      if (err?.code === 'ER_DUP_ENTRY' || err?.code === '23505') {
        throw new ConflictException('Email already in use');
      }
      throw err;
    }
  }

  async findByEmail(email: string): Promise<User> {
    const user = await this.userRepository.findOne({ where: { email } });
    if (!user) {
  throw new NotFoundException('User not found');
    }
    return user;
  }

  async findOne(id: number): Promise<User> {
    const user = await this.userRepository.findOne({ where: { id } });
    if (!user) {
  throw new NotFoundException('User not found');
    }
    return user;
  }

  async update(id: number, updateUserDto: UpdateUserDto): Promise<User> {
    const exists = await this.userRepository.findOne({ where: { id } });
    if (!exists) {
      throw new NotFoundException('User not found');
    }
    try {
      await this.userRepository.update(id, updateUserDto);
    } catch (err: any) {
      if (err?.code === 'ER_DUP_ENTRY' || err?.code === '23505') {
        throw new ConflictException('Email already in use');
      }
      throw err;
    }
    return this.findOne(id);
  }

  async remove(id: number): Promise<void> {
    const result = await this.userRepository.delete(id);
    if (!result.affected) {
      throw new NotFoundException('User not found');
    }
  }
}
