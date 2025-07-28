import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { FabricService } from "./fabric.service";
import { Fabric } from "./entities/fabric.entity";
import { User } from "../user/entities/user.entity";

@Module({
  imports: [TypeOrmModule.forFeature([Fabric, User])],
  providers: [FabricService],
  exports: [FabricService],
})
export class FabricModule {}
