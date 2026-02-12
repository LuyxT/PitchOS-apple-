import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { JwtPayload } from '../auth/dto/jwt-payload.dto';
import { FilesService } from './files.service';
import {
  CompleteUploadDto,
  CreateFolderDto,
  RegisterUploadDto,
  ShareFileDto,
} from './dto/files.dto';

@ApiTags('files')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('files')
export class FilesController {
  constructor(private readonly filesService: FilesService) {}

  @Get('bootstrap')
  async bootstrap(@CurrentUser() user: JwtPayload) {
    return this.filesService.bootstrap(user);
  }

  @Get('usage')
  async usage(@CurrentUser() user: JwtPayload) {
    return this.filesService.getUsage(user.orgId);
  }

  @Get('folders')
  async folders(@CurrentUser() user: JwtPayload) {
    return this.filesService.listFolders(user);
  }

  @Post('folders')
  async createFolder(@CurrentUser() user: JwtPayload, @Body() body: CreateFolderDto) {
    return this.filesService.createFolder(user, body);
  }

  @Get()
  async list(
    @CurrentUser() user: JwtPayload,
    @Query('q') q?: string,
    @Query('type') type?: string,
    @Query('folderPath') folderPath?: string,
    @Query('includeTrash') includeTrash = 'false',
    @Query('limit') limit = '50',
    @Query('cursor') cursor?: string,
  ) {
    return this.filesService.listFiles(
      user,
      q,
      type,
      folderPath,
      includeTrash === 'true',
      Number(limit),
      cursor,
    );
  }

  @Post('register')
  async register(@CurrentUser() user: JwtPayload, @Body() body: RegisterUploadDto) {
    return this.filesService.registerUpload(user, body);
  }

  @Post(':id/complete')
  async complete(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() body: CompleteUploadDto,
  ) {
    return this.filesService.completeUpload(user, id, body);
  }

  @Get(':id/download')
  async download(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.filesService.downloadUrl(user, id);
  }

  @Post(':id/share')
  async share(@CurrentUser() user: JwtPayload, @Param('id') id: string, @Body() body: ShareFileDto) {
    return this.filesService.share(user, id, body.userIds);
  }

  @Post(':id/trash')
  async trash(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.filesService.moveToTrash(user, id);
  }

  @Post(':id/restore')
  async restore(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.filesService.restore(user, id);
  }

  @Delete(':id')
  async hardDelete(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.filesService.hardDelete(user, id);
  }

  @Get('tools/largest')
  async largest(@CurrentUser() user: JwtPayload, @Query('limit') limit = '20') {
    return this.filesService.largestFiles(user, Number(limit));
  }

  @Get('tools/oldest')
  async oldest(@CurrentUser() user: JwtPayload, @Query('limit') limit = '20') {
    return this.filesService.oldestFiles(user, Number(limit));
  }
}
