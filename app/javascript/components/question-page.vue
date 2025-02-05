<template lang="pug">
div
  template(v-if='question === null || currentUser === null')
    loadingQuestionPagePlaceholder
  template(v-else)
    questionEdit(
      :question='question',
      :answerCount='answerCount',
      :isAnswerCountUpdated='isAnswerCountUpdated',
      :currentUser='currentUser',
      @afterUpdateQuestion='fetchQuestion(questionId)')
    template(v-if='hasAiQuestion && isAdminOrMentor()')
      ai_answer(:text='question.ai_answer')
    answers(
      :questionId='questionId',
      :questionUser='question.user',
      :currentUser='currentUser',
      @updateAnswerCount='updateAnswerCount',
      @solveQuestion='solveQuestion',
      @cancelSolveQuestion='cancelSolveQuestion')
</template>
<script>
import CSRF from 'csrf'
import QuestionEdit from 'components/question-edit.vue'
import AIAnswer from 'components/ai-answer.vue'
import Answers from 'answers.vue'
import LoadingQuestionPagePlaceholder from 'loading-question-page-placeholder.vue'

export default {
  name: 'QuestionPage',
  components: {
    LoadingQuestionPagePlaceholder: LoadingQuestionPagePlaceholder,
    /* app/javascript/loading-question-page-placeholder.vue */
    questionEdit: QuestionEdit,
    ai_answer: AIAnswer,
    answers: Answers
  },
  props: {
    currentUserId: { type: Number, required: true },
    questionId: { type: String, required: true }
  },
  data() {
    return {
      question: null,
      currentUser: null,
      answerCount: 0,
      isAnswerCountUpdated: false
    }
  },
  computed: {
    hasAiQuestion() {
      return (
        this.question.ai_answer !== null && this.question.ai_answer.length > 0
      )
    }
  },
  created() {
    this.fetchQuestion(this.questionId)
    this.fetchUser(this.currentUserId)
  },
  methods: {
    fetchQuestion(id) {
      fetch(`/api/questions/${id}.json`, {
        method: 'GET',
        headers: {
          'X-Requested-With': 'XMLHttpRequest',
          'X-CSRF-Token': CSRF.getToken()
        },
        credentials: 'same-origin'
      })
        .then((response) => {
          return response.json()
        })
        .then((question) => {
          this.question = question
        })
        .catch((error) => {
          console.warn(error)
        })
    },
    fetchUser(id) {
      fetch(`/api/users/${id}.json`, {
        method: 'GET',
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin',
        redirect: 'manual'
      })
        .then((response) => {
          return response.json()
        })
        .then((user) => {
          this.currentUser = user
        })
        .catch((error) => {
          console.warn(error)
        })
    },
    solveQuestion(answer) {
      this.question.correct_answer = answer
    },
    cancelSolveQuestion() {
      this.question.correct_answer = null
    },
    updateAnswerCount(count) {
      this.answerCount = count
      this.isAnswerCountUpdated = true
    },
    isAdminOrMentor() {
      return (
        this.currentUser.roles.includes('admin') ||
        this.currentUser.roles.includes('mentor')
      )
    }
  }
}
</script>
