import { Request, Response, NextFunction } from 'express';
import { Poll, PollOption, PollVote } from '../models';
import { ApiError } from '../middleware/error';

export async function createPoll(req: Request, res: Response, next: NextFunction) {
  try {
    const { team_id, question, options } = req.body;
    if (!team_id || !question || !Array.isArray(options) || options.length < 2) {
      throw new ApiError(400, 'team_id, question e pelo menos 2 options são obrigatórios');
    }
    const poll = await Poll.create({ team_id, question, created_by: req.user!.id });
    const createdOptions = await Promise.all(
      options.map((text: string) => PollOption.create({ poll_id: poll.id, text }))
    );
    res.status(201).json({
      ...poll.toJSON(),
      options: createdOptions.map((o) => ({ id: o.id, text: o.text, votes: 0 })),
      my_vote: null,
    });
  } catch (err) {
    next(err);
  }
}

async function withResults(polls: Poll[], userId: number) {
  const pollIds = polls.map((p) => p.id);
  if (pollIds.length === 0) return [];

  const options = await PollOption.findAll({ where: { poll_id: pollIds } });
  const votes = await PollVote.findAll({ where: { poll_id: pollIds } });

  const votesByOption = new Map<number, number>();
  const myVoteByPoll = new Map<number, number>();
  for (const v of votes) {
    votesByOption.set(v.option_id, (votesByOption.get(v.option_id) || 0) + 1);
    if (v.user_id === userId) myVoteByPoll.set(v.poll_id, v.option_id);
  }

  return polls.map((p) => ({
    ...p.toJSON(),
    options: options
      .filter((o) => o.poll_id === p.id)
      .map((o) => ({ id: o.id, text: o.text, votes: votesByOption.get(o.id) || 0 })),
    my_vote: myVoteByPoll.get(p.id) ?? null,
  }));
}

export async function listPolls(req: Request, res: Response, next: NextFunction) {
  try {
    const teamId = Number(req.query.teamId);
    if (!teamId) throw new ApiError(400, 'teamId é obrigatório');
    const polls = await Poll.findAll({ where: { team_id: teamId }, order: [['created_at', 'DESC']] });
    const result = await withResults(polls, req.user!.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

// Edita uma sondagem existente. A pergunta pode ser alterada a qualquer
// momento; as opções só podem ser substituídas enquanto a sondagem ainda
// não tiver nenhum voto — mudar as opções depois de já haver votos
// invalidaria os votos já registados.
export async function updatePoll(req: Request, res: Response, next: NextFunction) {
  try {
    const poll = await Poll.findByPk(req.params.id);
    if (!poll) throw new ApiError(404, 'Sondagem não encontrada');
    if (req.user!.role !== 'admin' && poll.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes editar sondagens da tua equipa');
    }

    const { question, options } = req.body;
    if (question !== undefined) {
      if (!question) throw new ApiError(400, 'question não pode ficar vazia');
      poll.question = question;
      await poll.save();
    }

    if (options !== undefined) {
      const existingVotes = await PollVote.count({ where: { poll_id: poll.id } });
      if (existingVotes > 0) {
        throw new ApiError(
          400,
          'Não é possível alterar as opções de uma sondagem que já tem votos — edita apenas a pergunta, ou elimina a sondagem'
        );
      }
      if (!Array.isArray(options) || options.length < 2) {
        throw new ApiError(400, 'São precisas pelo menos 2 opções');
      }
      await PollOption.destroy({ where: { poll_id: poll.id } });
      await Promise.all(options.map((text: string) => PollOption.create({ poll_id: poll.id, text })));
    }

    const [result] = await withResults([poll], req.user!.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}

// Elimina uma sondagem, incluindo as suas opções e os votos já registados.
export async function deletePoll(req: Request, res: Response, next: NextFunction) {
  try {
    const poll = await Poll.findByPk(req.params.id);
    if (!poll) throw new ApiError(404, 'Sondagem não encontrada');
    if (req.user!.role !== 'admin' && poll.team_id !== req.user!.team_id) {
      throw new ApiError(403, 'Só podes eliminar sondagens da tua equipa');
    }

    const options = await PollOption.findAll({ where: { poll_id: poll.id } });
    const optionIds = options.map((o) => o.id);
    if (optionIds.length > 0) {
      await PollVote.destroy({ where: { option_id: optionIds } });
    }
    await PollOption.destroy({ where: { poll_id: poll.id } });
    await poll.destroy();

    res.status(200).json({ message: 'Sondagem eliminada com sucesso' });
  } catch (err) {
    next(err);
  }
}

export async function votePoll(req: Request, res: Response, next: NextFunction) {
  try {
    const pollId = Number(req.params.id);
    const { option_id } = req.body;
    if (!option_id) throw new ApiError(400, 'option_id é obrigatório');

    const option = await PollOption.findOne({ where: { id: option_id, poll_id: pollId } });
    if (!option) throw new ApiError(404, 'Opção não encontrada nesta sondagem');

    const existing = await PollVote.findOne({ where: { poll_id: pollId, user_id: req.user!.id } });
    if (existing) {
      existing.option_id = option_id;
      await existing.save();
    } else {
      await PollVote.create({ poll_id: pollId, option_id, user_id: req.user!.id });
    }

    const poll = await Poll.findByPk(pollId);
    const [result] = await withResults(poll ? [poll] : [], req.user!.id);
    res.status(200).json(result);
  } catch (err) {
    next(err);
  }
}
